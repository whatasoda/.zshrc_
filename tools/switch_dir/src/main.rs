use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
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
        base: String,
        #[arg(long)]
        prefix: String,
        #[arg(long)]
        dir_prefix: Option<String>,
        #[arg(long)]
        expected_repo: Option<String>,
    },
    /// Resolve a key to a directory path
    Resolve {
        #[arg(long)]
        base: String,
        #[arg(long)]
        prefix: String,
        #[arg(long)]
        dir_prefix: Option<String>,
        #[arg(long)]
        expected_repo: Option<String>,
        #[arg(long)]
        key: String,
        #[arg(long)]
        json: Option<String>,
    },
    /// Refresh the cache
    Refresh {
        #[arg(long)]
        base: String,
        #[arg(long)]
        prefix: String,
        #[arg(long)]
        dir_prefix: Option<String>,
        #[arg(long)]
        expected_repo: Option<String>,
    },
}

#[derive(Serialize, Deserialize)]
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

fn cmd_list(base: &str, prefix: &str, dir_prefix: Option<&str>, expected_repo: Option<&str>) {
    let resolved_base = resolve_base(base, expected_repo);

    // Try to load from cache first
    let candidates = if let Some(cache) = load_cache(&resolved_base) {
        // Spawn background refresh
        if let Ok(exe) = std::env::current_exe() {
            let mut cmd = Command::new(exe);
            cmd.arg("refresh")
                .arg("--base")
                .arg(&resolved_base)
                .arg("--prefix")
                .arg(prefix);
            if let Some(dp) = dir_prefix {
                cmd.arg("--dir-prefix").arg(dp);
            }
            let _ = cmd.spawn();
        }
        cache.candidates
    } else {
        // No cache, build synchronously
        let cache = refresh_cache(&resolved_base, prefix, dir_prefix);
        cache.candidates
    };

    for candidate in candidates {
        println!("{}", candidate);
    }
}

fn cmd_resolve(
    base: &str,
    prefix: &str,
    dir_prefix: Option<&str>,
    expected_repo: Option<&str>,
    key: &str,
    json: Option<&str>,
) {
    let resolved_base = resolve_base(base, expected_repo);

    // Try JSON mapping first
    if let Some(json_str) = json {
        if let Ok(map) = serde_json::from_str::<HashMap<String, String>>(json_str) {
            if let Some(subpath) = map.get(key) {
                let full_path = Path::new(&resolved_base).join(subpath);
                if full_path.is_dir() {
                    println!("{}", full_path.display());
                    return;
                }
            }
        }
    }

    let target_dir = Path::new(&resolved_base).join(prefix);

    // Exact match
    let exact_path = target_dir.join(key);
    if exact_path.is_dir() {
        println!("{}", exact_path.display());
        return;
    }

    // Prefix match
    if let Some(dp) = dir_prefix {
        let prefixed_path = target_dir.join(format!("{}{}", dp, key));
        if prefixed_path.is_dir() {
            println!("{}", prefixed_path.display());
            return;
        }
    }

    // Not found - exit with error
    std::process::exit(1);
}

fn cmd_refresh(base: &str, prefix: &str, dir_prefix: Option<&str>, expected_repo: Option<&str>) {
    let resolved_base = resolve_base(base, expected_repo);
    refresh_cache(&resolved_base, prefix, dir_prefix);
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::List {
            base,
            prefix,
            dir_prefix,
            expected_repo,
        } => {
            cmd_list(&base, &prefix, dir_prefix.as_deref(), expected_repo.as_deref());
        }
        Commands::Resolve {
            base,
            prefix,
            dir_prefix,
            expected_repo,
            key,
            json,
        } => {
            cmd_resolve(
                &base,
                &prefix,
                dir_prefix.as_deref(),
                expected_repo.as_deref(),
                &key,
                json.as_deref(),
            );
        }
        Commands::Refresh {
            base,
            prefix,
            dir_prefix,
            expected_repo,
        } => {
            cmd_refresh(&base, &prefix, dir_prefix.as_deref(), expected_repo.as_deref());
        }
    }
}
