# Compatibility line — S/4HANA 2023 (`S4CORE` 108)

Long-lived Git branch: **`compat/s4-2023`**.  
`main` stays the fullest stack (e.g. S/4HANA 2025). Merge `main` → this branch periodically; resolve by keeping 108 substitutes.

## abapGit

| Setting | Value |
|---------|--------|
| URL | same as `main` (`sap-dex2file`) |
| Branch | **`compat/s4-2023`** |
| Package | e.g. `$EVOLVER_DEX2F` (not the Standalone package) |

Requires [abapGit ≥ 1.133.0](../README.md#prerequisite--abapgit-version) for `SRVB` auto-publish.

## Substitutions vs `main`

| Object | On `main` | On `compat/s4-2023` |
|--------|-----------|---------------------|
| `ZEVO_M_BPCustomer` | `I_BusinessPartnerCustomerDEX` | `I_BusinessPartnerCustomer` (slimmer fields) |
| `ZEVO_M_BPSupplier` | `I_BusinessPartnerSupplierDEX` | `I_BusinessPartnerSupplier` (slimmer fields) |
| `ZEVO_C_PurchRequisitionItem` | full DEX field list | omit 108-missing qty/block/quota fields |
| `ZEVO_O_OutboundDelivery` | `C_OutboundDeliveryDEX` | `I_DeliveryDocument` (`where` category `J`; key aliased) |
| `ZEVO_O_BillingDocumentItem` | `I_BillingDocumentItemDEX` | `C_BillingDocumentItemBasicDEX` (no `CreatedByUser` / creation stamp on item — use `_OutboundDelivery` if needed) |
| Sales contract / SO item / schedule | org + partner fields | those columns omitted (not on local CDS) |

## Behaviour changes for clients

- C2C: `$expand=_SoldToParty` on **SalesContract** / **SalesDocumentItem** / **BillingDocumentItem** is **not** available on this line (fields absent). Use lean `BusinessPartner` entity set or MD joins by known partner IDs from other sources when needed.
- Delivery header still supports `_SoldToParty` / `_ShipToParty` when present on `I_DeliveryDocument`.
- MD role entity sets are thinner than the 2025 DEX roles.

## After pull

Mass-activate `ZEVO_*` DDLS → SRVD → SRVB. Paste any remaining activate errors back so the branch can trim further.
