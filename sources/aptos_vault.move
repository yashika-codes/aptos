module my_address::aptos_vault {
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::table::{Self, Table};
    use std::signer;

    /// Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_INSUFFICIENT_FUNDS: u64 = 2;
    const E_NO_ALLOCATION: u64 = 3;

    struct VaultSignerCapability has key {
        cap: account::SignerCapability,
    }

    struct Vault has key {
        admin: address,
        vault_address: address,
        total_balance: u64,
        allocations: Table<address, u64>,
        tokens_deposited_events: EventHandle<TokensDepositedEvent>,
    }

    struct TokensDepositedEvent has drop, store {
        amount: u64,
    }

    /// Initializes the module and sets up the vault capability
    public entry fun init_vault(admin: &signer) {
        let admin_address = signer::address_of(admin);
        
        // Creating a resource account to act as the autonomous vault
        let (vault_signer, vault_cap) = account::create_resource_account(admin, b"VAULT_SEED");
        let vault_address = signer::address_of(&vault_signer);

        move_to(admin, VaultSignerCapability { cap: vault_cap });

        move_to(&vault_signer, Vault {
            admin: admin_address,
            vault_address: vault_address,
            total_balance: 0,
            allocations: table::new<address, u64>(),
            tokens_deposited_events: account::new_event_handle<TokensDepositedEvent>(&vault_signer),
        });
    }

    /// Part 1 Task: Deposit tokens into the vault directly using vault_address
    public entry fun deposit_tokens(admin: &signer, vault_address: address, amount: u64) acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        
        // Assertions check the admin address using the admin field from the Vault struct
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);

        // Transfer funds from admin to the vault address
        coin::transfer<AptosCoin>(admin, vault.vault_address, amount);
        
        vault.total_balance = vault.total_balance + amount;
        
        event::emit_event(&mut vault.tokens_deposited_events, TokensDepositedEvent { amount });
    }

    /// Part 1 Task: Allocate tokens to a specific beneficiary address (Admin only)
    public entry fun allocate_tokens(admin: &signer, vault_address: address, recipient: address, amount: u64) acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        
        // Verify caller is admin
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
        // Ensure vault has enough unallocated balance
        assert!(vault.total_balance >= amount, E_INSUFFICIENT_FUNDS);

        // Update or initialize allocation mapping
        if (table::contains(&vault.allocations, recipient)) {
            let current_alloc = table::borrow_mut(&mut vault.allocations, recipient);
            *current_alloc = *current_alloc + amount;
        } else {
            table::add(&mut vault.allocations, recipient, amount);
        };
    }

    /// Part 1 Task: Recipients claim their allocated tokens dynamically
    public entry fun claim_tokens(recipient: &signer, vault_address: address) acquires Vault, VaultSignerCapability {
        let recipient_addr = signer::address_of(recipient);
        let vault = borrow_global_mut<Vault>(vault_address);
        
        // Ensure an allocation exists for the caller
        assert!(table::contains(&vault.allocations, recipient_addr), E_NO_ALLOCATION);
        
        let amount = *table::borrow(&vault.allocations, recipient_addr);
        assert!(amount > 0, E_NO_ALLOCATION);
        assert!(vault.total_balance >= amount, E_INSUFFICIENT_FUNDS);

        // Clear the allocation record before transfer to protect against reentrancy
        table::remove(&mut vault.allocations, recipient_addr);
        vault.total_balance = vault.total_balance - amount;

        // Retrieve the signer capability from the admin account to sign the payout
        let vault_signer_cap = &borrow_global<VaultSignerCapability>(vault.admin).cap;
        let vault_signer = account::create_signer_with_capability(vault_signer_cap);

        // Transfer the tokens from the vault resource account to the recipient
        coin::transfer<AptosCoin>(&vault_signer, recipient_addr, amount);
    }

    /// Part 1 Task: Withdraw unallocated funds back to the admin address (Admin only)
    public entry fun withdraw_tokens(admin: &signer, vault_address: address, amount: u64) acquires Vault, VaultSignerCapability {
        let vault = borrow_global_mut<Vault>(vault_address);
        let admin_addr = signer::address_of(admin);
        
        // Verify caller is admin
        assert!(vault.admin == admin_addr, E_NOT_ADMIN);
        assert!(vault.total_balance >= amount, E_INSUFFICIENT_FUNDS);

        vault.total_balance = vault.total_balance - amount;

        let vault_signer_cap = &borrow_global<VaultSignerCapability>(admin_addr).cap;
        let vault_signer = account::create_signer_with_capability(vault_signer_cap);

        // Transfer funds back to the admin account
        coin::transfer<AptosCoin>(&vault_signer, admin_addr, amount);
    }

    /// Modify view functions to take vault_address directly
    #[view]
    public fun get_vault_balance(vault_address: address): u64 acquires Vault {
        let vault = borrow_global<Vault>(vault_address);
        vault.total_balance
    }

    #[view]
    public fun get_recipient_allocation(vault_address: address, recipient: address): u64 acquires Vault {
        let vault = borrow_global<Vault>(vault_address);
        if (table::contains(&vault.allocations, recipient)) {
            *table::borrow(&vault.allocations, recipient)
        } else {
            0
        }
    }

    // ==========================================
    // BONUS: Ownership Transfer Function
    // ==========================================
    public entry fun transfer_ownership(admin: &signer, vault_address: address, new_admin: address) acquires Vault {
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.admin == signer::address_of(admin), E_NOT_ADMIN);
        vault.admin = new_admin;
    }
}