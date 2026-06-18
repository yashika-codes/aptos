# Aptos Direct Address Vault Contract

An optimized, secure vault smart contract built with the Move programming language for the Aptos blockchain. 

## Project Architecture & Refactoring Overview

The primary objective of this project was to refactor an inefficient resource-lookup pattern. 

### Performance Changes
* **Old Implementation:** The system previously relied on computing the dynamic resource address at runtime by taking an `admin_address` string input and executing an expensive global storage capability lookup through `get_vault_address`.
* **Optimized Implementation:** The updated contract directly accepts a pre-derived `vault_address: address` as a core parameter in every structural function signature. This removes runtime storage calculation lookup costs entirely and reduces global gas consumption profiles.

### Security Layout
Access control validation checks are strictly implemented across all execution pathways. The runtime queries the explicit `Vault` resource structure hosted at the user-supplied `vault_address`, validating that the caller's signing key completely matches the authoritative administrative record address:
```rust
assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
