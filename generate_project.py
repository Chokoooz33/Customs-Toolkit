import os
import uuid

def generate_uuid():
    return uuid.uuid4().hex[:24].upper()

def main():
    os.makedirs("CustomsToolkit.xcodeproj/xcshareddata/xcschemes", exist_ok=True)
    
    # Collect project files relative to their group
    app_files_rel = []
    app_asset_catalogs_rel = []
    for root, dirs, files in os.walk("CustomsToolkit"):
        for d in list(dirs):
            if d.endswith(".xcassets"):
                full_catalog = os.path.join(root, d)
                app_asset_catalogs_rel.append(os.path.relpath(full_catalog, "CustomsToolkit"))
                dirs.remove(d)
        for f in files:
            if f.endswith(".swift") or f.endswith(".strings") or f.endswith(".json") or f == "Info.plist":
                full = os.path.join(root, f)
                rel = os.path.relpath(full, "CustomsToolkit")
                app_files_rel.append(rel)
                
    test_files_rel = []
    for root, _, files in os.walk("CustomsToolkitTests"):
        for f in files:
            if f.endswith(".swift") or f == "Info.plist":
                full = os.path.join(root, f)
                rel = os.path.relpath(full, "CustomsToolkitTests")
                test_files_rel.append(rel)
                
    file_entries = {}
    build_file_entries = {}
    
    # Generate PBX IDs
    for f in app_files_rel + app_asset_catalogs_rel + test_files_rel:
        f_id = generate_uuid()
        b_id = generate_uuid()
        file_entries[f] = f_id
        build_file_entries[f] = b_id
        
    # Project objects IDs
    proj_id = generate_uuid()
    main_group_id = generate_uuid()
    app_group_id = generate_uuid()
    test_group_id = generate_uuid()
    products_group_id = generate_uuid()
    
    app_target_id = generate_uuid()
    test_target_id = generate_uuid()
    
    app_product_id = generate_uuid()
    test_product_id = generate_uuid()
    
    app_sources_id = generate_uuid()
    app_resources_id = generate_uuid()
    test_sources_id = generate_uuid()
    
    target_dependency_id = generate_uuid()
    container_item_proxy_id = generate_uuid()
    
    proj_config_list_id = generate_uuid()
    app_config_list_id = generate_uuid()
    test_config_list_id = generate_uuid()
    
    proj_debug_config_id = generate_uuid()
    proj_release_config_id = generate_uuid()
    app_debug_config_id = generate_uuid()
    app_release_config_id = generate_uuid()
    test_debug_config_id = generate_uuid()
    test_release_config_id = generate_uuid()
    
    pbx = []
    pbx.append("// !$*UTF8*$!")
    pbx.append("{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {")
    
    # PBXBuildFile
    pbx.append("/* Begin PBXBuildFile section */")
    for f, b_id in build_file_entries.items():
        f_id = file_entries[f]
        name = os.path.basename(f)
        if f.endswith(".swift") or f.endswith(".strings") or f.endswith(".json") or f.endswith(".xcassets"):
            pbx.append(f"\t\t{b_id} /* {name} in Sources/Resources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {name} */; }};")
    pbx.append("/* End PBXBuildFile section */\n")
    
    # PBXContainerItemProxy
    pbx.append("/* Begin PBXContainerItemProxy section */")
    pbx.append(f"\t\t{container_item_proxy_id} /* PBXContainerItemProxy */ = {{\n\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = {proj_id} /* Project object */;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = {app_target_id};\n\t\t\tremoteInfo = CustomsToolkit;\n\t\t}};")
    pbx.append("/* End PBXContainerItemProxy section */\n")
    
    # PBXFileReference
    pbx.append("/* Begin PBXFileReference section */")
    pbx.append(f"\t\t{app_product_id} /* CustomsToolkit.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CustomsToolkit.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    pbx.append(f"\t\t{test_product_id} /* CustomsToolkitTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = CustomsToolkitTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for f, f_id in file_entries.items():
        name = os.path.basename(f)
        ext = os.path.splitext(f)[1]
        ftype = "folder.assetcatalog" if f.endswith(".xcassets") else ("sourcecode.swift" if ext == ".swift" else ("text.plist.xml" if ext == ".plist" else ("text.json" if ext == ".json" else "text.plist.strings")))
        pbx.append(f"\t\t{f_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = \"{f}\"; sourceTree = \"<group>\"; }};")
    pbx.append("/* End PBXFileReference section */\n")
    
    # PBXGroup
    pbx.append("/* Begin PBXGroup section */")
    pbx.append(f"\t\t{main_group_id} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{app_group_id} /* CustomsToolkit */,\n\t\t\t\t{test_group_id} /* CustomsToolkitTests */,\n\t\t\t\t{products_group_id} /* Products */,\n\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    
    app_children = ",\n".join([f"\t\t\t\t{file_entries[f]} /* {os.path.basename(f)} */" for f in app_files_rel + app_asset_catalogs_rel])
    pbx.append(f"\t\t{app_group_id} /* CustomsToolkit */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{app_children}\n\t\t\t);\n\t\t\tpath = CustomsToolkit;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    
    test_children = ",\n".join([f"\t\t\t\t{file_entries[f]} /* {os.path.basename(f)} */" for f in test_files_rel])
    pbx.append(f"\t\t{test_group_id} /* CustomsToolkitTests */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{test_children}\n\t\t\t);\n\t\t\tpath = CustomsToolkitTests;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    
    pbx.append(f"\t\t{products_group_id} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{app_product_id} /* CustomsToolkit.app */,\n\t\t\t\t{test_product_id} /* CustomsToolkitTests.xctest */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    pbx.append("/* End PBXGroup section */\n")
    
    # PBXNativeTarget
    pbx.append("/* Begin PBXNativeTarget section */")
    pbx.append(f"""\t\t{app_target_id} /* CustomsToolkit */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {app_config_list_id} /* Build configuration list for PBXNativeTarget "CustomsToolkit" */;
\t\t\tbuildPhases = (
\t\t\t\t{app_sources_id} /* Sources */,
\t\t\t\t{app_resources_id} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = CustomsToolkit;
\t\t\tproductName = CustomsToolkit;
\t\t\tproductReference = {app_product_id} /* CustomsToolkit.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};""")
    
    pbx.append(f"""\t\t{test_target_id} /* CustomsToolkitTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {test_config_list_id} /* Build configuration list for PBXNativeTarget "CustomsToolkitTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{test_sources_id} /* Sources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{target_dependency_id} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = CustomsToolkitTests;
\t\t\tproductName = CustomsToolkitTests;
\t\t\tproductReference = {test_product_id} /* CustomsToolkitTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};""")
    pbx.append("/* End PBXNativeTarget section */\n")
    
    # PBXProject
    pbx.append("/* Begin PBXProject section */")
    pbx.append(f"""\t\t{proj_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{app_target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t\t{test_target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t\tTestTargetID = {app_target_id};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_config_list_id} /* Build configuration list for PBXProject "CustomsToolkit" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tar,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_id};
\t\t\tproductRefGroup = {products_group_id} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{app_target_id} /* CustomsToolkit */,
\t\t\t\t{test_target_id} /* CustomsToolkitTests */,
\t\t\t);
\t\t}};""")
    pbx.append("/* End PBXProject section */\n")
    
    # PBXResourcesBuildPhase
    app_resources = ",\n".join([f"\t\t\t\t{build_file_entries[f]} /* {os.path.basename(f)} in Resources */" for f in app_files_rel + app_asset_catalogs_rel if f.endswith(".strings") or f.endswith(".json") or f.endswith(".xcassets")])
    pbx.append("/* Begin PBXResourcesBuildPhase section */")
    pbx.append(f"""\t\t{app_resources_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{app_resources}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};""")
    pbx.append("/* End PBXResourcesBuildPhase section */\n")
    
    # PBXSourcesBuildPhase
    app_sources = ",\n".join([f"\t\t\t\t{build_file_entries[f]} /* {os.path.basename(f)} in Sources */" for f in app_files_rel if f.endswith(".swift")])
    test_sources = ",\n".join([f"\t\t\t\t{build_file_entries[f]} /* {os.path.basename(f)} in Sources */" for f in test_files_rel if f.endswith(".swift")])
    pbx.append("/* Begin PBXSourcesBuildPhase section */")
    pbx.append(f"""\t\t{app_sources_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{app_sources}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};""")
    pbx.append(f"""\t\t{test_sources_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{test_sources}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};""")
    pbx.append("/* End PBXSourcesBuildPhase section */\n")
    
    # PBXTargetDependency
    pbx.append("/* Begin PBXTargetDependency section */")
    pbx.append(f"\t\t{target_dependency_id} /* PBXTargetDependency */ = {{\n\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = {app_target_id} /* CustomsToolkit */;\n\t\t\ttargetProxy = {container_item_proxy_id} /* PBXContainerItemProxy */;\n\t\t}};")
    pbx.append("/* End PBXTargetDependency section */\n")
    
    # XCBuildConfiguration
    pbx.append("/* Begin XCBuildConfiguration section */")
    pbx.append(f"""\t\t{proj_debug_config_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{proj_release_config_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{app_debug_config_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = CustomsToolkit/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.customstoolkit.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{app_release_config_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = CustomsToolkit/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.customstoolkit.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{test_debug_config_id} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = CustomsToolkitTests/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@loader_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.customstoolkit.appTests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/CustomsToolkit.app/CustomsToolkit";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{test_release_config_id} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = CustomsToolkitTests/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@loader_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.customstoolkit.appTests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/CustomsToolkit.app/CustomsToolkit";
\t\t\t}};
\t\t\tname = Release;
\t\t}};""")
    pbx.append("/* End XCBuildConfiguration section */\n")
    
    # XCConfigurationList
    pbx.append("/* Begin XCConfigurationList section */")
    pbx.append(f"""\t\t{proj_config_list_id} /* Build configuration list for PBXProject "CustomsToolkit" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_debug_config_id} /* Debug */,
\t\t\t\t{proj_release_config_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{app_config_list_id} /* Build configuration list for PBXNativeTarget "CustomsToolkit" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{app_debug_config_id} /* Debug */,
\t\t\t\t{app_release_config_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{test_config_list_id} /* Build configuration list for PBXNativeTarget "CustomsToolkitTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{test_debug_config_id} /* Debug */,
\t\t\t\t{test_release_config_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};""")
    pbx.append("/* End XCConfigurationList section */\n")
    
    pbx.append("\t};\n\trootObject = " + proj_id + " /* Project object */;\n}")
    
    with open("CustomsToolkit.xcodeproj/project.pbxproj", "w") as f:
        f.write("\n".join(pbx))
        
    print("Project regenerated successfully.")

if __name__ == "__main__":
    main()
