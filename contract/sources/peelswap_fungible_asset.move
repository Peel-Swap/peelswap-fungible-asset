/// Module: peelswap::peelswap_fungible_asset
/// 
/// This module implements the PEEL token for the Peelswap protocol, built on top of the Cedra Framework.
/// 
/// The PEEL token is a managed fungible asset with public minting functionality against the CEDRA token,
/// and includes administrative functions for configuration and management.
/// 
/// Key Features:
/// - Creation and management of the PEEL fungible asset with metadata.
/// - Public minting mechanism allowing users to mint PEEL tokens by providing 1 CEDRA tokens.
/// - Administrative controls for configuring mint rates and managing asset metadata.
/// - Integration with Cedra Framework's asset, object, and coin primitives.
///
/// The module is designed for secure, flexible, and transparent management of the PEEL token within the Peelswap ecosystem.
/// Run test: $ cedra move test
module peelswap::peelswap_fungible_asset{
    use cedra_framework::fungible_asset::{Self, MintRef, TransferRef, Metadata};
    use cedra_framework::object::{Self, Object};
    use cedra_framework::primary_fungible_store;
    use cedra_framework::coin;
    use cedra_framework::cedra_coin::{CedraCoin};
    use std::error;
    use std::signer;
    use std::string::utf8;
    use std::option;

    /// Only fungible asset metadata owner can make changes.
    const ENOT_OWNER: u64 = 1;
    const EMINT_RATE_ZERO: u64 = 2;

    const ASSET_SYMBOL: vector<u8> = b"PEEL";
    const ASSET_NAME: vector<u8> = b"Peelswap Fungible Asset";

    #[resource_group_member(group = cedra_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer of fungible assets.
    struct PeelswapFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        admin: address,
        mint_rate: u64, // [mint_rate] == PEEL / CEDRA
    }

    #[test_only]
    fun init_module_for_test(admin: signer) {
        init_module(&admin)
    }

    /// Initialize metadata object and store the refs.
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(ASSET_NAME),
            utf8(ASSET_SYMBOL),
            8,
            utf8(b"https://peelswap.xyz/peelswap_fungible_asset.json"),
            utf8(b"http://peelswap.xyz"),
        );

        // Create mint/transfer refs to allow creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            PeelswapFungibleAsset { 
                mint_ref, 
                transfer_ref,
                admin: signer::address_of(admin),
                mint_rate: 1000,
            }
        );
    }

    #[view]
    /// Return the address of the managed fungible asset that's created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@peelswap, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    public entry fun authorized_mint(admin: &signer, to: address, amount: u64) acquires PeelswapFungibleAsset {
        let asset = get_metadata();
        let managed_fungible_asset = authorized_borrow_refs(admin, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, to_wallet, fa);
    }

    public entry fun set_mint_rate(admin: &signer, new_mint_rate: u64) acquires PeelswapFungibleAsset {
        let asset = get_metadata();
        let managed_mut = authorized_borrow_refs_mut(admin, asset);
        managed_mut.mint_rate = new_mint_rate;
    }

    /// Public mint: any user pays 1 CEDRA and receives 1000 PEEL.
    /// Amounts are in base units (8 decimals for both CEDRA and PEEL).
    public entry fun mint(user: &signer) acquires PeelswapFungibleAsset {
        let asset = get_metadata();
        let managed = borrow_refs(asset);

        let user_addr = signer::address_of(user);
        let admin_addr = managed.admin;
        let mint_rate = managed.mint_rate;
        assert!(mint_rate > 0, error::permission_denied(EMINT_RATE_ZERO));

        // Charge 1 CEDRA from caller by transferring to admin treasury.
        let one_cedra_amount: u64 = 100_000_000; // 1 CEDRA
        coin::transfer<CedraCoin>(user, admin_addr, one_cedra_amount);

        let peel_amount: u64 = mint_rate * one_cedra_amount;
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(user_addr, asset);
        let fa = fungible_asset::mint(&managed.mint_ref, peel_amount);
        fungible_asset::deposit_with_ref(&managed.transfer_ref, to_wallet, fa);
    }

    /// Transfer tokens from one account to another
    public entry fun transfer(sender: &signer, to: address, amount: u64) {
        let asset = get_metadata();
        let fa = primary_fungible_store::withdraw(sender, asset, amount);
        primary_fungible_store::deposit(to, fa);
    }

    /// Borrow the immutable reference of the refs of `metadata`.
    /// This validates that the signer is the admin.
    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &PeelswapFungibleAsset acquires PeelswapFungibleAsset {
        let refs = borrow_global<PeelswapFungibleAsset>(object::object_address(&asset));
        assert!(refs.admin == signer::address_of(owner), error::permission_denied(ENOT_OWNER));
        refs
    }

    /// Borrow the mutable reference of the refs of `metadata`.
    inline fun authorized_borrow_refs_mut(
        owner: &signer,
        asset: Object<Metadata>,
    ): &mut PeelswapFungibleAsset acquires PeelswapFungibleAsset {
        let refs = borrow_global_mut<PeelswapFungibleAsset>(object::object_address(&asset));
        assert!(refs.admin == signer::address_of(owner), error::permission_denied(ENOT_OWNER));
        refs
    }

    /// Borrow the immutable reference of the refs of `metadata` without admin check.
    inline fun borrow_refs(asset: Object<Metadata>): &PeelswapFungibleAsset acquires PeelswapFungibleAsset {
        borrow_global<PeelswapFungibleAsset>(object::object_address(&asset))
    }

    // =====================
    // Tests (inline)
    // =====================
    #[test_only]
    use cedra_framework::cedra_coin;
    #[test_only]
    use cedra_framework::account;
    #[test_only]
    use cedra_framework::primary_fungible_store as pfs;

    #[test(framework = @cedra_framework, admin = @peelswap, user = @0xb0b)]
    public entry fun test_mint_flow(framework: signer, admin: signer, user: signer) acquires PeelswapFungibleAsset {
        let admin_addr = signer::address_of(&admin);
        let user_addr = signer::address_of(&user);
        // Initialize Cedra coin and fund user with 2 CEDRA
        let (burn_cap, mint_cap) = cedra_coin::initialize_for_test(&framework);
        account::create_account_for_test(admin_addr);
        cedra_coin::mint(&framework, user_addr, 200_000_000); // 2 CEDRA

        // Initialize FA under peelswap address
        init_module(&admin);

        // Public mint: charges 1 CEDRA and mints 1000 PEEL
        mint(&user);

        // Check balances
        assert!(pfs::balance(user_addr, get_metadata()) == 1000 * 100_000_000, 0);
        assert!(coin::balance<CedraCoin>(user_addr) == 100_000_000, 1);
        assert!(coin::balance<CedraCoin>(admin_addr) == 100_000_000, 2);
        
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test(framework = @cedra_framework, admin = @peelswap)]
    public entry fun test_set_rate(framework: signer, admin: signer) acquires PeelswapFungibleAsset {
        let (burn_cap, mint_cap) = cedra_coin::initialize_for_test(&framework);
        account::create_account_for_test(signer::address_of(&admin));
        init_module(&admin);

        set_mint_rate(&admin, 42);
        assert!(borrow_refs(get_metadata()).mint_rate == 42, 0);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }
}