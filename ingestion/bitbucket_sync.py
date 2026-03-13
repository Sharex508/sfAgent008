from pathlib import Path

from git import Repo
from git.exc import GitCommandError
from project_paths import resolve_metadata_repo_path


def sync_repo(clone_url: str, repo_path: str = "./data/repo", branch: str = "main") -> str:
    """
    Clone a Bitbucket/Git repository if missing and pull latest changes thereafter.

    - If `repo_path` doesn't exist, performs a `git clone` from `clone_url` onto the given `branch`.
    - On subsequent runs, checks out `branch` and pulls from `origin`.
    - Returns the latest commit SHA (hex) of HEAD after syncing.

    Args:
        clone_url: The HTTPS clone URL of the git repository.
        repo_path: Local path where the repository should live. Defaults to "./data/repo".
        branch: Branch name to sync. Defaults to "main".

    Returns:
        The HEAD commit SHA as a string.
    """
    p = resolve_metadata_repo_path(Path(repo_path))
    # Ensure parent directories exist (e.g., ./data)
    p.parent.mkdir(parents=True, exist_ok=True)

    if not p.exists():
        # Clone fresh repository and checkout the requested branch
        Repo.clone_from(clone_url, str(p), branch=branch)

    repo = Repo(str(p))

    # Ensure the desired branch is checked out; if it doesn't exist locally, create it tracking origin
    try:
        repo.git.checkout(branch)
    except GitCommandError:
        # Fetch remote branch then create/reset local branch to track origin/<branch>
        repo.git.fetch("origin", branch)
        repo.git.checkout("-B", branch, f"origin/{branch}")

    # Pull latest changes from origin
    repo.remotes.origin.pull()

    return repo.head.commit.hexsha


if __name__ == "__main__":
    # Simple CLI for manual runs
    import os
    import sys

    default_url = "https://Harsha508@bitbucket.org/carrierhvac-asia/natt-sfdx.git"
    url = os.getenv("BITBUCKET_CLONE_URL") or (sys.argv[1] if len(sys.argv) > 1 else default_url)
    path = os.getenv("REPO_PATH") or (sys.argv[2] if len(sys.argv) > 2 else "./data/repo")
    branch = os.getenv("REPO_BRANCH") or (sys.argv[3] if len(sys.argv) > 3 else "main")

    sha = sync_repo(url, path, branch)
    print(sha)
