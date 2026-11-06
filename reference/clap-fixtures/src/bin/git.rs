use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};
use serde::Serialize;

/// A fictional version control system
#[derive(Parser, Debug, Serialize)]
#[command(name = "git", version = "2.0.0", term_width = 0)]
struct Git {
    #[command(flatten)]
    global: GlobalOpts,

    /// Required subcommand
    #[command(subcommand)]
    command: Commands,
}

#[derive(Args, Debug, Serialize)]
struct GlobalOpts {
    /// Run as if started in PATH
    #[arg(short = 'C', value_name = "PATH")]
    directory: Option<PathBuf>,

    /// Suppress output
    #[arg(short, long)]
    quiet: bool,
}

#[derive(Subcommand, Debug, Serialize)]
enum Commands {
    /// Clone a repository into a new directory.
    ///
    /// Clones a repository into a newly created directory and creates
    /// remote-tracking branches for each branch in the cloned repository.
    Clone {
        /// The repository to clone from
        remote: String,
        /// The directory to clone into
        directory: Option<PathBuf>,
        /// Create a shallow clone with this many commits
        #[arg(long)]
        depth: Option<u32>,
    },
    /// Add file contents to the index
    Add(AddArgs),
    /// Show the working tree status
    #[command(alias = "st")]
    Status,
    /// Record changes to the repository
    #[command(visible_alias = "ci")]
    Commit {
        /// Use the given message as the commit message
        #[arg(short, long)]
        message: String,
        /// Stage all modified files first
        #[arg(short, long)]
        all: bool,
    },
    /// Manage the set of tracked repositories
    Remote {
        /// Show remote URLs
        #[arg(short, long)]
        verbose: bool,
        #[command(subcommand)]
        command: Option<RemoteCommands>,
    },
    /// Stash the changes in a dirty working directory
    #[command(subcommand)]
    Stash(StashCommands),
    Gc,
    /// Remove files from the working tree and the index
    Rm {
        /// Files to remove
        files: Vec<String>,
    },
}

#[derive(Args, Debug, Serialize)]
struct AddArgs {
    /// Don't actually add the files
    #[arg(short = 'n', long)]
    dry_run: bool,
    /// Files to add content from
    paths: Vec<PathBuf>,
}

#[derive(Subcommand, Debug, Serialize)]
enum RemoteCommands {
    /// Add a remote named NAME for the repository at URL
    Add {
        /// Name of the remote
        name: String,
        /// URL of the remote
        url: String,
    },
    /// Remove the remote named NAME
    #[command(alias = "rm")]
    Remove {
        /// Name of the remote
        name: String,
    },
}

#[derive(Subcommand, Debug, Serialize)]
enum StashCommands {
    /// Save local modifications to a new stash entry
    Push {
        /// Stash message
        #[arg(short, long)]
        message: Option<String>,
    },
    /// Remove a stash entry and apply it
    Pop {
        #[arg(long)]
        index: bool,
    },
}

fn main() {
    clap_fixtures::run::<Git>();
}
