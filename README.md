
# Payload 2024

This repository is home to the University of Massachussetts Amherst Rocket Team's payload source code for the 2024 NASA SLI competition.

_If you are planning on writing a new readme.md for a branch, I highly reccomend using https://readme.so/editor_


## Git Flow

This repository follows a basic feature-branching flow. While not the most secure flow, it permits us to make fast changes, as we do not have multiple environments to deploy to.

Feature branching works as so:
1. User creates a new issue on the [Payload 2024](https://github.com/orgs/UMass-Rocket-Team/projects/3) Project
2. User creates a new branch off of main with the same name and issue ID as the previously mentioned issue.
3. User writes their code locally, then commits and pushes code to their branch
4. User requests review of their branch from another team member
5. After user recieves approval, and all tests are passed, they can merge to main!

This flow method allows us to make sure that no user's individual change can break the entire codebase. Plus, git flow is a good practice to get used to!

![An image from Microsoft of feature branching flow](https://learn.microsoft.com/en-us/azure/devops/repos/git/media/branching-guidance/featurebranching.png?view=azure-devops)

_An image from [Microsoft](https://learn.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops) of feature branching_

## Running Tests

All unit and end-to-end tasks will be run as part of the git Continuous Integration (CI) pipeline. This means that all unit tests will be run every time a user pushes to their feature branch. Pull requests will not go through unless all tests are passed.

