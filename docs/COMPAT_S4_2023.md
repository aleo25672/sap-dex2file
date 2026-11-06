# Compatibility line — S/4HANA 2023 (`S4CORE` 108)

Long-lived Git branch: **`compat/s4-2023`**.  
`main` stays the fullest stack (e.g. S/4HANA 2025). Merge `main` → this branch periodically; resolve by keeping 108 substitutes.

## abapGit

| Setting | Value |
|---------|--------|
| URL | same as `main` (`sap-dex2file`) |
| Branch | **`compat/s4-2023`** |
| Package | e.g. `$EVOLVER_DEX2F` (not the Standalone package) |

### Service bindings (`SRVB`) — ADT only on this line

Hand-written / sample `zevo_*.srvb.xml` **fail deserialize** on this stack (`Error during deserialization` / `Import of object ZEVO_* failed`). They are **not** in `compat/s4-2023`.

After CDS + SRVD activate:

1. ADT → New **Service Binding** with the same name as the definition (`ZEVO_C2P`, `ZEVO_C2C`, `ZEVO_GENERALLEDGER`, `ZEVO_MD`, `ZEVO_ORG`).
2. Type **OData V4 - Web API** → Activate → **Publish**.
3. On later abapGit pulls: **Uncheck** any **Delete local** for those `SRVB` / `G4BA` objects.

Optional later: on a system where bindings already work, **stage** the real serialized `SRVB` from abapGit into Git (do not invent XML by hand).

## Substitutions vs `main`

| Object | On `main` | On `compat/s4-2023` |
|--------|-----------|---------------------|
| `ZEVO_M_BPCustomer` | `I_BusinessPartnerCustomerDEX` | `I_BusinessPartnerCustomer` (slimmer fields) |
| `ZEVO_M_BPSupplier` | `I_BusinessPartnerSupplierDEX` | `I_BusinessPartnerSupplier` (slimmer fields) |
| `ZEVO_C_PurchRequisitionItem` | full DEX field list | omit 108-missing qty/block/quota fields |
| `ZEVO_O_OutboundDelivery` | `C_OutboundDeliveryDEX` | `I_DeliveryDocument` (`where` category `J`; key aliased) |
| `ZEVO_O_BillingDocumentItem` | `I_BillingDocumentItemDEX` | `C_BillingDocumentItemBasicDEX` (no `CreatedByUser` on item) |
| Sales contract / SO item / schedule | org + partner fields | those columns omitted (not on local CDS) |
| `SRVB` files | present on `main` (may still fail deserialize) | **omitted** — create in ADT |

## Behaviour changes for clients

- C2C: `$expand=_SoldToParty` on **SalesContract** / **SalesDocumentItem** / **BillingDocumentItem** is **not** available on this line. Use lean `BusinessPartner` or MD joins when needed.
- Delivery header still supports `_SoldToParty` / `_ShipToParty` when present on `I_DeliveryDocument`.
- MD role entity sets are thinner than the 2025 DEX roles.

## After pull

1. Mass-activate `ZEVO_*` DDLS + SRVD.  
2. Create/publish five bindings in ADT (above).  
3. Paste any remaining activate errors for further CDS trim.
