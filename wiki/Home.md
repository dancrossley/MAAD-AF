# MAAD-AF Wiki

This folder is a repo-local wiki for understanding how MAAD-AF is put together and how to operate it safely on a new host.

It is organized around the questions that come up most often when changing or testing the tool:

- [Execution Flow](./Execution-Flow.md)
- [Authentication and Access](./Authentication-and-Access.md)
- [Feature to Session Matrix](./Feature-to-Session-Matrix.md)
- [Code Structure and Refactor Plan](./Code-Structure-and-Refactor-Plan.md)

## What This Wiki Covers

- how MAAD-AF starts and loads its code
- how the menu dispatches feature functions
- why there are multiple access options in the `Access` menu
- which features depend on which service session
- where the current structure is strong, where it is fragile, and how to refactor it safely

## Recommended Reading Order

1. [Execution Flow](./Execution-Flow.md)
2. [Authentication and Access](./Authentication-and-Access.md)
3. [Feature to Session Matrix](./Feature-to-Session-Matrix.md)
4. [Code Structure and Refactor Plan](./Code-Structure-and-Refactor-Plan.md)

## Notes

- This wiki reflects the current Entra-based branch structure and behavior.
- Some feature paths still use alias-backed legacy AzureAD cmdlets internally, but their intended session model is documented here using the current Entra/Graph architecture.
