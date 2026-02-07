# Deploy Extension to Business Central

Deploy the current extension to the configured Business Central sandbox environment.

## Instructions

1. **Verify the project compiles** by checking for AL syntax errors

2. **Run the deployment script**:
   ```powershell
   .\scripts\deploy.ps1
   ```

3. **Monitor deployment output** for:
   - Compilation errors
   - Deployment failures
   - Schema sync issues

4. **Verify deployment** by checking the Extensions page in BC

## Pre-Deployment Checklist

Before deploying, ensure:
- [ ] All AL files have valid syntax
- [ ] Object IDs are within allocated range (50100-50199)
- [ ] No duplicate object IDs
- [ ] Captions are defined for all user-facing elements
- [ ] Permission sets are updated for new objects

## Common Issues

### Schema Sync Errors
If deployment fails with schema errors:
1. Check `launch.json` has `"schemaUpdateMode": "ForceSync"`
2. Consider if data migration is needed
3. For breaking changes, may need to uninstall/reinstall

### Compilation Errors
Read the error output carefully:
- Missing dependencies → Check app.json dependencies
- Undefined references → Verify object names match exactly
- Type mismatches → Check field types in table relations

### Authentication Issues
If BC authentication fails:
1. Ensure you're signed into VS Code with correct account
2. Check tenant ID in launch.json
3. Verify environment name is correct

## Manual Deployment Alternative

If scripts fail, use VS Code:
1. Press `Ctrl+Shift+P`
2. Run "AL: Publish without Debugging"
3. Or press `Ctrl+F5`

## Post-Deployment

After successful deployment:
1. Open Business Central in browser
2. Navigate to the feature you deployed
3. Test basic functionality
4. Check for any runtime errors in the Event Log
