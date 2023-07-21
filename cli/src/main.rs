pub(crate) mod cli;
pub(crate) mod deploy;
pub(crate) mod subgraph;


#[tokio::main]
async fn main() -> anyhow::Result<()> {
    cli::main().await 
}