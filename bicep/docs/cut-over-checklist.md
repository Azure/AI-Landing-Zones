# Production Cut-Over Checklist

## Pre-Cut-Over Validation

### ✅ **Phase 1: Code Validation**

- [x] All module files exist in `bicep/infra/modules/`
- [x] No Bicep lint errors in `main-modularized.bicep`
- [x] No Bicep lint errors in any module file
- [x] All parameters preserved from original `main.bicep`
- [x] All outputs preserved from original `main.bicep`
- [x] Type imports correctly reference `common/types.bicep`

### 📋 **Phase 2: Build & Compilation** (Manual Testing Required)

- [ ] Compile main template:
  ```powershell
  az bicep build --file bicep/infra/main-modularized.bicep
  ```

- [ ] Verify ARM JSON output size < 4MB:
  ```powershell
  $armFile = Get-Item "bicep/infra/main-modularized.json"
  $sizeMB = $armFile.Length / 1MB
  Write-Host "Template size: $sizeMB MB"
  ```

- [ ] Compile all individual modules:
  ```powershell
  Get-ChildItem bicep/infra/modules/*.bicep | ForEach-Object {
    az bicep build --file $_.FullName
  }
  ```

### 🧪 **Phase 3: Test Deployment**

- [ ] Create test resource group:
  ```powershell
  az group create --name rg-ailz-test --location eastus
  ```

- [ ] Run What-If analysis:
  ```powershell
  az deployment group what-if `
    --resource-group rg-ailz-test `
    --template-file bicep/infra/main-modularized.bicep `
    --parameters bicep/infra/main.bicepparam
  ```

- [ ] Review What-If output:
  - [ ] No unexpected deletions
  - [ ] No unexpected modifications
  - [ ] Only expected creations

- [ ] Deploy to test environment:
  ```powershell
  az deployment group create `
    --resource-group rg-ailz-test `
    --template-file bicep/infra/main-modularized.bicep `
    --parameters bicep/infra/main.bicepparam `
    --confirm-with-what-if
  ```

- [ ] Validate test deployment:
  - [ ] All resources created successfully
  - [ ] Private endpoints are connected
  - [ ] VNet peering is established (if configured)
  - [ ] NSGs are attached to subnets
  - [ ] Private DNS zones have VNet links
  - [ ] Key Vault is accessible
  - [ ] Storage account is accessible
  - [ ] Container registry is accessible

### 🔧 **Phase 4: Preprovision Script Testing**

- [ ] Test preprovision script with new structure:
  ```bash
  ./bicep/scripts/preprovision.sh
  ```

- [ ] Verify script output:
  - [ ] No errors reported
  - [ ] Template specs created/updated (if applicable)
  - [ ] Wrapper paths replaced correctly (if applicable)

### 📝 **Phase 5: Documentation Review**

- [ ] Review `bicep/docs/modularization-summary.md`
- [ ] Review `bicep/docs/quick-start-modular.md`
- [ ] Review `bicep/docs/module-integration-guide.md`
- [ ] Update team documentation (if any)
- [ ] Update README.md (if necessary)

## Cut-Over Execution

### 🚀 **Phase 6: Production Cut-Over**

**Timing**: Schedule during maintenance window or low-usage period.

**Steps**:

1. [ ] **Backup Current State**:
   ```powershell
   # Backup original main.bicep
   Copy-Item bicep/infra/main.bicep bicep/infra/main.bicep.backup -Force
   
   # Export current deployment template (if already deployed)
   az deployment group export `
     --resource-group <production-rg> `
     --name <deployment-name> `
     > bicep/infra/current-deployment-backup.json
   ```

2. [ ] **Replace Main File**:
   ```powershell
   # Replace with modularized version
   Copy-Item bicep/infra/main-modularized.bicep bicep/infra/main.bicep -Force
   
   # Verify replacement
   Get-Item bicep/infra/main.bicep | Select-Object Name, Length, LastWriteTime
   ```

3. [ ] **Commit Changes**:
   ```bash
   git add bicep/infra/main.bicep
   git add bicep/infra/modules/
   git add bicep/docs/
   git commit -m "feat: modularize main.bicep for improved maintainability and template size compliance"
   ```

4. [ ] **Create Tag/Release**:
   ```bash
   git tag -a v2.0.0-modular -m "Modularized architecture release"
   git push origin v2.0.0-modular
   ```

### 🔍 **Phase 7: Post-Cut-Over Validation**

- [ ] **CI/CD Pipeline Test**:
  - [ ] Trigger GitHub Actions workflow manually
  - [ ] Verify workflow completes successfully
  - [ ] Check Azure Portal for deployed resources

- [ ] **Production What-If** (if applicable):
  ```powershell
  az deployment group what-if `
    --resource-group <production-rg> `
    --template-file bicep/infra/main.bicep `
    --parameters bicep/infra/main.bicepparam
  ```

- [ ] **Production Deployment** (if updating existing):
  ```powershell
  az deployment group create `
    --resource-group <production-rg> `
    --template-file bicep/infra/main.bicep `
    --parameters bicep/infra/main.bicepparam `
    --mode Incremental `
    --confirm-with-what-if
  ```

- [ ] **Post-Deployment Validation**:
  - [ ] All resources are healthy
  - [ ] No configuration drift
  - [ ] Private endpoints are connected
  - [ ] Services are accessible
  - [ ] Monitoring is active

### 📢 **Phase 8: Communication**

- [ ] **Notify Team**:
  - Announce successful cut-over
  - Share documentation links
  - Schedule training session (if needed)

- [ ] **Update Documentation**:
  - Update deployment procedures
  - Update architecture diagrams
  - Update troubleshooting guides

## Rollback Plan

### ⚠️ **If Issues Occur**

**Option 1: Revert to Backup**

```powershell
# Restore original main.bicep
Copy-Item bicep/infra/main.bicep.backup bicep/infra/main.bicep -Force

# Redeploy (if necessary)
az deployment group create `
  --resource-group <rg-name> `
  --template-file bicep/infra/main.bicep `
  --parameters bicep/infra/main.bicepparam
```

**Option 2: Use Git History**

```bash
# Revert commit
git revert HEAD

# Force push (if necessary)
git push origin main --force
```

**Option 3: Use Previous Template Spec** (if using template specs)

```powershell
# Deploy from previous template spec version
az deployment group create `
  --resource-group <rg-name> `
  --template-spec <template-spec-id> `
  --template-spec-version <previous-version>
```

## Success Criteria

✅ **Cut-over is successful if:**

1. All module files compile without errors
2. Main template builds successfully
3. What-If analysis shows expected changes only
4. Test deployment completes successfully
5. Production deployment completes without errors
6. All resources are healthy post-deployment
7. No service disruptions
8. CI/CD pipeline runs successfully
9. Team can work with new structure
10. Documentation is complete and accurate

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Code Validation | 15 min | None |
| Build & Compilation | 10 min | Azure CLI installed |
| Test Deployment | 25-30 min | Test environment |
| Preprovision Script | 5 min | Script dependencies |
| Documentation Review | 15 min | None |
| Production Cut-Over | 10 min | All previous phases |
| Post-Cut-Over Validation | 20-30 min | Production access |
| Communication | 30 min | Team availability |

**Total Estimated Time**: 2-3 hours

## Key Contacts

- **Bicep Lead**: [Name]
- **DevOps Lead**: [Name]
- **Azure Admin**: [Name]
- **On-Call Support**: [Contact Info]

## Notes

- This is a **non-breaking change** - parameters and outputs are identical
- Deployments can be done incrementally (no recreation required)
- Rollback is straightforward if issues arise
- Team training recommended but not required for basic use

## Post-Cut-Over Actions

- [ ] Monitor deployment metrics for 24-48 hours
- [ ] Document any issues encountered
- [ ] Gather team feedback
- [ ] Schedule retrospective (if major migration)
- [ ] Update runbooks with new structure
- [ ] Archive backup files after stability period

---

**Checklist Version**: 1.0  
**Last Updated**: January 2025  
**Prepared By**: GitHub Copilot  
**Approved By**: [To be filled]
