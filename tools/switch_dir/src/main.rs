use clap::{Parser, Subcommand};
use serde::Deserialize;
use std::collections::HashMap;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Parser)]
#[command(name = "switch-dir")]
#[command(about = "Fast directory switching helper")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// List directory candidates for fzf
    List {
        #[arg(long)]
        config: String,
    },
    /// Resolve a key to a directory path
    Resolve {
        #[arg(long)]
        config: String,
        #[arg(long)]
        key: String,
    },
    /// Refresh the cache
    Refresh {
        #[arg(long)]
        config: String,
    },
}

#[derive(Deserialize)]
struct Config {
    base: String,
    prefix: String,
    dir_prefix: Option<String>,
    expected_repo: Option<String>,
    aliases: Option<HashMap<String, String>>,
}

#[derive(serde::Serialize, Deserialize)]
struct Cache {
    base: String,
    directories: Vec<String>,
    candidates: Vec<String>,
}

fn get_cache_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("switch_dir")
}

fn get_cache_id(base: &str) -> String {
    base.replace('/', "_").replace('~', "_home_")
}

fn get_cache_path(base: &str) -> PathBuf {
    get_cache_dir().join(format!("{}.json", get_cache_id(base)))
}

fn expand_tilde(path: &str) -> String {
    if path.starts_with('~') {
        if let Some(home) = dirs::home_dir() {
            return path.replacen('~', home.to_str().unwrap_or("~"), 1);
        }
    }
    path.to_string()
}

fn load_config(path: &str) -> Result<Config, Box<dyn std::error::Error>> {
    let expanded = expand_tilde(path);
    let content = fs::read_to_string(&expanded)?;
    let config: Config = serde_json::from_str(&content)?;
    Ok(config)
}

fn resolve_base(default_base: &str, expected_repo: Option<&str>) -> String {
    let expanded = expand_tilde(default_base);

    if let Some(repo) = expected_repo {
        if let Ok(output) = Command::new("git")
            .args(["rev-parse", "--show-toplevel"])
            .output()
        {
            if output.status.success() {
                let git_root = String::from_utf8_lossy(&output.stdout).trim().to_string();
                if let Some(dir_name) = Path::new(&git_root).file_name() {
                    if dir_name.to_str() == Some(repo) {
                        return git_root;
                    }
                }
            }
        }
    }

    expanded
}

fn collect_candidates(
    base: &str,
    prefix: &str,
    dir_prefix: Option<&str>,
) -> (Vec<String>, Vec<String>) {
    let target_dir = Path::new(base).join(prefix);
    let mut directories = Vec::new();
    let mut candidates = Vec::new();

    if let Ok(entries) = fs::read_dir(&target_dir) {
        for entry in entries.flatten() {
            if entry.path().is_dir() {
                if let Some(name) = entry.file_name().to_str() {
                    directories.push(name.to_string());
                    candidates.push(name.to_string());

                    if let Some(dp) = dir_prefix {
                        if let Some(stripped) = name.strip_prefix(dp) {
                            let stripped_path = target_dir.join(stripped);
                            if !stripped_path.exists() {
                                candidates.push(stripped.to_string());
                            }
                        }
                    }
                }
            }
        }
    }

    directories.sort();
    candidates.sort();

    (directories, candidates)
}

fn load_cache(base: &str) -> Option<Cache> {
    let path = get_cache_path(base);
    let content = fs::read_to_string(path).ok()?;
    serde_json::from_str(&content).ok()
}

fn save_cache(cache: &Cache) -> io::Result<()> {
    let cache_dir = get_cache_dir();
    fs::create_dir_all(&cache_dir)?;
    let path = get_cache_path(&cache.base);
    let content = serde_json::to_string(cache)?;
    fs::write(path, content)
}

fn refresh_cache(base: &str, prefix: &str, dir_prefix: Option<&str>) -> Cache {
    let (directories, candidates) = collect_candidates(base, prefix, dir_prefix);
    let cache = Cache {
        base: base.to_string(),
        directories,
        candidates,
    };
    let _ = save_cache(&cache);
    cache
}

fn cmd_list(config: &Config, config_path: &str) {
    let resolved_base = resolve_base(&config.base, config.expected_repo.as_deref());

    let candidates = if let Some(cache) = load_cache(&resolved_base) {
        // Spawn background refresh
        if let Ok(exe) = std::env::current_exe() {
            let _ = Command::new(exe)
                .arg("refresh")
                .arg("--config")
                .arg(config_path)
                .spawn();
        }
        cache.candidates
    } else {
        let cache = refresh_cache(
            &resolved_base,
            &config.prefix,
            config.dir_prefix.as_deref(),
        );
        cache.candidates
    };

    for candidate in candidates {
        println!("{}", candidate);
    }
}

fn cmd_resolve(config: &Config, key: &str) {
    let resolved_base = resolve_base(&config.base, config.expected_repo.as_deref());

    // Try aliases first
    if let Some(aliases) = &config.aliases {
        if let Some(subpath) = aliases.get(key) {
            let full_path = Path::new(&resolved_base).join(subpath);
            if full_path.is_dir() {
                println!("{}", full_path.display());
                return;
            }
        }
    }

    let target_dir = Path::new(&resolved_base).join(&config.prefix);

    // Exact match
    let exact_path = target_dir.join(key);
    if exact_path.is_dir() {
        println!("{}", exact_path.display());
        return;
    }

    // Prefix match
    if let Some(dp) = &config.dir_prefix {
        let prefixed_path = target_dir.join(format!("{}{}", dp, key));
        if prefixed_path.is_dir() {
            println!("{}", prefixed_path.display());
            return;
        }
    }

    std::process::exit(1);
}

fn cmd_refresh(config: &Config) {
    let resolved_base = resolve_base(&config.base, config.expected_repo.as_deref());
    refresh_cache(
        &resolved_base,
        &config.prefix,
        config.dir_prefix.as_deref(),
    );
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::List { config } => {
            let cfg = load_config(&config).unwrap_or_else(|e| {
                eprintln!("Failed to load config: {}", e);
                std::process::exit(1);
            });
            cmd_list(&cfg, &config);
        }
        Commands::Resolve { config, key } => {
            let cfg = load_config(&config).unwrap_or_else(|e| {
                eprintln!("Failed to load config: {}", e);
                std::process::exit(1);
            });
            cmd_resolve(&cfg, &key);
        }
        Commands::Refresh { config } => {
            let cfg = load_config(&config).unwrap_or_else(|e| {
                eprintln!("Failed to load config: {}", e);
                std::process::exit(1);
            });
            cmd_refresh(&cfg);
        }
    }
}
