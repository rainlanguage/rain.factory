use anyhow::Result;
use clap::command;
use clap::{Parser, Subcommand};

pub mod deploy;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    factory: Factory,
}

#[derive(Subcommand)]
pub enum Factory {
    CrossDeploy(deploy::CrossDeploy)
}

pub async fn dispatch(factory: Factory) -> Result<()> {
    match factory {
        Factory::CrossDeploy(deploy) => deploy::deploy(deploy).await 
    }
}

pub async fn main() -> Result<()> {
    tracing::subscriber::set_global_default(tracing_subscriber::fmt::Subscriber::new())?;

    let cli = Cli::parse();
    dispatch(cli.factory).await 
}
