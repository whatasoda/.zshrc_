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
        config: String,
    },
    /// Resolve a key to a directory path
    Resolve {
        #[arg(long)]
        config: String,
        #[arg(long)]
        key: String,
    },
    /// Refresh the cache (includes worktree discovery)
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
    #[serde(default)]
    #[allow(dead_code)]
    expected_repo: Option<String>, // Kept for backwards compatibility
    aliases: Option<HashMap<String, String>>,
    cache_dir: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct Cache {
    base: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    worktrees: Option<Vec<String>>,
    paths: HashMap<String, String>,
    candidates: Vec<String>,
}

fn expand_tilde(path: &str) -> String {
    if path.starts_with('~') {
        if let Some(home) = dirs::home_dir() {
            return path.replacen('~', home.to_str().unwrap_or("~"), 1);
        }
    }
    path.to_string()
}

fn get_cache_id(base: &str) -> String {
    base.replace('/', "_").replace('~', "_home_")
}

fn get_cache_dir(config: &Config) -> PathBuf {
    config
        .cache_dir
        .as_ref()
        .map(|d| PathBuf::from(expand_tilde(d)))
        .unwrap_or_else(|| {
            dirs::cache_dir()
                .unwrap_or_else(|| PathBuf::from("/tmp"))
                .join("switch_dir")
        })
}

fn get_cache_path(config: &Config, base: &str) -> PathBuf {
    get_cache_dir(config).join(format!("{}.json", get_cache_id(base)))
}

fn load_config(path: &str) -> Result<Config, Box<dyn std::error::Error>> {
    let expanded = expand_tilde(path);
    let content = fs::read_to_string(&expanded)?;
    let config: Config = serde_json::from_str(&content)?;
    Ok(config)
}

fn collect_paths(
    base: &str,
    prefix: &str,
    dir_prefix: Option<&str>,
) -> (HashMap<String, String>, Vec<String>) {
    let target_dir = if prefix == "." {
        PathBuf::from(base)
    } else {
        Path::new(base).join(prefix)
    };
    let mut paths: HashMap<String, String> = HashMap::new();
    let mut candidates: Vec<String> = Vec::new();

    if let Ok(entries) = fs::read_dir(&target_dir) {
        for entry in entries.flatten() {
            if entry.path().is_dir() {
                if let Some(name) = entry.file_name().to_str() {
                    let full_path = entry.path().to_string_lossy().to_string();

                    paths.insert(name.to_string(), full_path.clone());
                    candidates.push(name.to_string());

                    if let Some(dp) = dir_prefix {
                        if let Some(stripped) = name.strip_prefix(dp) {
                            let stripped_path = target_dir.join(stripped);
                            if !stripped_path.exists() {
                                paths.insert(stripped.to_string(), full_path);
                                candidates.push(stripped.to_string());
                            }
                        }
                    }
                }
            }
        }
    }

    candidates.sort();
    (paths, candidates)
}

fn load_cache(config: &Config, base: &str) -> Option<Cache> {
    let path = get_cache_path(config, base);
    let content = fs::read_to_string(path).ok()?;
    serde_json::from_str(&content).ok()
}

fn find_matching_cache(config: &Config) -> Option<(Cache, String)> {
    let cwd = std::env::current_dir().ok()?;
    let cwd_str = cwd.to_str()?;
    let base = expand_tilde(&config.base);

    // Load only the cache for this config's base
    let cache = load_cache(config, &base)?;

    // Check base first
    if cwd_str.starts_with(&cache.base) {
        let base = cache.base.clone();
        return Some((cache, base));
    }

    // Check worktrees
    if let Some(worktrees) = &cache.worktrees {
        for wt in worktrees {
            if cwd_str.starts_with(wt) {
                let matched = wt.clone();
                return Some((cache, matched));
            }
        }
    }

    None
}

fn transform_path(path: &str, from_base: &str, to_base: &str) -> String {
    if from_base == to_base {
        path.to_string()
    } else if let Some(suffix) = path.strip_prefix(from_base) {
        format!("{}{}", to_base, suffix)
    } else {
        path.to_string()
    }
}

fn find_effective_base(base: &str, worktrees: &[String]) -> String {
    if let Ok(cwd) = std::env::current_dir() {
        if let Some(cwd_str) = cwd.to_str() {
            // Check if cwd is in any worktree
            for wt in worktrees {
                if cwd_str.starts_with(wt) {
                    return wt.clone();
                }
            }
        }
    }
    // Default to main base
    base.to_string()
}

fn save_cache(config: &Config, cache: &Cache) -> io::Result<()> {
    let cache_dir = get_cache_dir(config);
    fs::create_dir_all(&cache_dir)?;
    let path = get_cache_path(config, &cache.base);
    let content = serde_json::to_string(cache)?;
    fs::write(path, content)
}

fn refresh_cache(
    config: &Config,
    base: &str,
    prefix: &str,
    dir_prefix: Option<&str>,
    worktrees: Option<Vec<String>>,
) -> Cache {
    let (paths, candidates) = collect_paths(base, prefix, dir_prefix);
    let cache = Cache {
        base: base.to_string(),
        worktrees,
        paths,
        candidates,
    };
    let _ = save_cache(config, &cache);
    cache
}

fn cmd_list(config: &Config) {
    // Try cache-first (no git command)
    if let Some((cache, _matched_base)) = find_matching_cache(config) {
        for candidate in &cache.candidates {
            println!("{}", candidate);
        }
        return;
    }

    // Cache miss - use default base (root worktree)
    let base = expand_tilde(&config.base);
    let cache = if let Some(cache) = load_cache(config, &base) {
        cache
    } else {
        let worktrees = get_worktrees(&base);
        refresh_cache(
            config,
            &base,
            &config.prefix,
            config.dir_prefix.as_deref(),
            if worktrees.is_empty() { None } else { Some(worktrees) },
        )
    };

    for candidate in cache.candidates {
        println!("{}", candidate);
    }
}

fn cmd_resolve(config: &Config, key: &str) {
    // Handle special key for refresh
    if key == "--refresh" {
        cmd_refresh(config);
        return;
    }

    // Try cache-first (no git command)
    if let Some((cache, matched_base)) = find_matching_cache(config) {
        // Try aliases first
        if let Some(aliases) = &config.aliases {
            if let Some(subpath) = aliases.get(key) {
                let full_path = if subpath == "." {
                    PathBuf::from(&matched_base)
                } else {
                    Path::new(&matched_base).join(subpath)
                };
                if full_path.is_dir() {
                    println!("{}", full_path.display());
                    return;
                }
            }
        }

        // Try cache paths (transform to matched_base if in worktree)
        if let Some(path) = cache.paths.get(key) {
            let transformed = transform_path(path, &cache.base, &matched_base);
            if Path::new(&transformed).is_dir() {
                println!("{}", transformed);
                return;
            }
        }
    }

    // Cache miss - determine effective base considering worktrees
    let base = expand_tilde(&config.base);
    let worktrees = get_worktrees(&base);
    let effective_base = find_effective_base(&base, &worktrees);

    // Try aliases with effective base
    if let Some(aliases) = &config.aliases {
        if let Some(subpath) = aliases.get(key) {
            let full_path = if subpath == "." {
                PathBuf::from(&effective_base)
            } else {
                Path::new(&effective_base).join(subpath)
            };
            if full_path.is_dir() {
                // Save cache for future use
                let _ = refresh_cache(
                    config,
                    &base,
                    &config.prefix,
                    config.dir_prefix.as_deref(),
                    if worktrees.is_empty() { None } else { Some(worktrees) },
                );
                println!("{}", full_path.display());
                return;
            }
        }
    }

    // Try existing cache with path transformation
    if let Some(cache) = load_cache(config, &base) {
        if let Some(path) = cache.paths.get(key) {
            let transformed = transform_path(path, &base, &effective_base);
            if Path::new(&transformed).is_dir() {
                println!("{}", transformed);
                return;
            }
        }
    }

    // Refresh and retry
    let cache = refresh_cache(
        config,
        &base,
        &config.prefix,
        config.dir_prefix.as_deref(),
        if worktrees.is_empty() { None } else { Some(worktrees) },
    );
    if let Some(path) = cache.paths.get(key) {
        let transformed = transform_path(path, &base, &effective_base);
        if Path::new(&transformed).is_dir() {
            println!("{}", transformed);
            return;
        }
    }

    std::process::exit(1);
}

fn get_worktrees(base: &str) -> Vec<String> {
    let output = Command::new("git")
        .args(["worktree", "list", "--porcelain"])
        .current_dir(base)
        .output();

    let mut worktrees = Vec::new();

    if let Ok(output) = output {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            for line in stdout.lines() {
                if let Some(path) = line.strip_prefix("worktree ") {
                    worktrees.push(path.to_string());
                }
            }
        }
    }

    worktrees
}

fn cmd_refresh(config: &Config) {
    let base = expand_tilde(&config.base);

    // Get all worktrees
    let worktrees = get_worktrees(&base);

    // Collect paths from main repo
    let (paths, candidates) = collect_paths(&base, &config.prefix, config.dir_prefix.as_deref());

    let cache = Cache {
        base: base.clone(),
        worktrees: if worktrees.is_empty() {
            None
        } else {
            Some(worktrees.clone())
        },
        paths,
        candidates,
    };

    if let Err(e) = save_cache(config, &cache) {
        eprintln!("Failed to save cache: {}", e);
        std::process::exit(1);
    }

    if worktrees.is_empty() {
        println!("Refreshed cache (no worktrees)");
    } else {
        println!("Refreshed cache with {} worktrees:", worktrees.len());
        for wt in &worktrees {
            println!("  {}", wt);
        }
    }
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::List { config } => {
            let cfg = load_config(&config).unwrap_or_else(|e| {
                eprintln!("Failed to load config: {}", e);
                std::process::exit(1);
            });
            cmd_list(&cfg);
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
