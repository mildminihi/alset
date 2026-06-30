#!/usr/bin/env python3
"""Regenerate Alset.xcodeproj from sources under Alset/."""

from __future__ import annotations

import hashlib
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT_DIR = ROOT / "Alset.xcodeproj"
SCHEME_DIR = PROJECT_DIR / "xcshareddata" / "xcschemes"
WORKSPACE_DIR = PROJECT_DIR / "project.xcworkspace"
SECRETS_XCCONFIG = ROOT / "Alset/Config/Secrets.xcconfig"
SECRETS_EXAMPLE = ROOT / "Alset/Config/Secrets.xcconfig.example"

PRODUCT_NAME = "Alset"
BUNDLE_ID = "com.mildminihi.alset"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "6.0"
INFOPLIST_FILE = "Alset/Info.plist"

SWIFT_SOURCES = [
    "Alset/AlsetApp.swift",
    "Alset/Config/AppSecrets.swift",
    "Alset/Models/TeslaVehicleModels.swift",
    "Alset/Services/TeslaNetworkManager.swift",
    "Alset/Services/TeslaOAuthService.swift",
    "Alset/Services/TeslaAuthRepository.swift",
    "Alset/Services/SupabaseAuthService.swift",
    "Alset/Utilities/PKCE.swift",
    "Alset/ViewModels/AppViewModel.swift",
    "Alset/Views/LoginView.swift",
    "Alset/Views/RootView.swift",
    "Alset/Views/TeslaConnectView.swift",
    "Alset/Views/VehicleDashboardView.swift",
]


def uid(name: str) -> str:
    digest = hashlib.sha1(f"com.mildminihi.alset.{name}".encode()).hexdigest()
    return digest[:24].upper()


IDS = {
    "project": uid("project"),
    "target": uid("target"),
    "project_config_list": uid("project_config_list"),
    "target_config_list": uid("target_config_list"),
    "sources_phase": uid("sources_phase"),
    "frameworks_phase": uid("frameworks_phase"),
    "resources_phase": uid("resources_phase"),
    "main_group": uid("main_group"),
    "products_group": uid("products_group"),
    "alset_group": uid("alset_group"),
    "config_group": uid("group:Alset/Config"),
    "models_group": uid("group:Alset/Models"),
    "services_group": uid("group:Alset/Services"),
    "utilities_group": uid("group:Alset/Utilities"),
    "viewmodels_group": uid("group:Alset/ViewModels"),
    "views_group": uid("group:Alset/Views"),
    "debug_project": uid("debug_project"),
    "release_project": uid("release_project"),
    "debug_target": uid("debug_target"),
    "release_target": uid("release_target"),
    "product_ref": uid("product_ref"),
    "secrets_xcconfig_ref": uid("secrets_xcconfig_ref"),
    "secrets_example_ref": uid("secrets_example_ref"),
    "infoplist_ref": uid("infoplist_ref"),
}


def file_ref_id(path: str) -> str:
    return uid(f"fileref:{path}")


def build_file_id(path: str) -> str:
    return uid(f"buildfile:{path}")


def ensure_secrets_xcconfig() -> None:
    if not SECRETS_XCCONFIG.exists():
        shutil.copy2(SECRETS_EXAMPLE, SECRETS_XCCONFIG)
        print(f"Created {SECRETS_XCCONFIG.relative_to(ROOT)}")


def pbxproj_content() -> str:
    file_refs: list[str] = []
    build_files: list[str] = []
    sources_entries: list[str] = []

    for path in SWIFT_SOURCES:
        ref = file_ref_id(path)
        bf = build_file_id(path)
        name = Path(path).name
        file_refs.append(
            f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
        )
        build_files.append(
            f"\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};"
        )
        sources_entries.append(f"\t\t\t\t{bf} /* {name} in Sources */,")

    file_refs.extend(
        [
            f"\t\t{IDS['infoplist_ref']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};",
            f"\t\t{IDS['secrets_xcconfig_ref']} /* Secrets.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Secrets.xcconfig; sourceTree = \"<group>\"; }};",
            f"\t\t{IDS['secrets_example_ref']} /* Secrets.xcconfig.example */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Secrets.xcconfig.example; sourceTree = \"<group>\"; }};",
            f"\t\t{IDS['product_ref']} /* {PRODUCT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PRODUCT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};",
        ]
    )

    common_target = f"""\
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = {INFOPLIST_FILE};
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";"""

    debug_project = f"""\
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};"""

    release_project = f"""\
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_VERSION = {SWIFT_VERSION};
\t\t\t\tVALIDATE_PRODUCT = YES;"""

    return f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{IDS['frameworks_phase']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{IDS['main_group']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{IDS['alset_group']} /* Alset */,
\t\t\t\t{IDS['products_group']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['products_group']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{IDS['product_ref']} /* {PRODUCT_NAME}.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['alset_group']} /* Alset */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_id('Alset/AlsetApp.swift')} /* AlsetApp.swift */,
\t\t\t\t{IDS['config_group']} /* Config */,
\t\t\t\t{IDS['infoplist_ref']} /* Info.plist */,
\t\t\t\t{IDS['models_group']} /* Models */,
\t\t\t\t{IDS['services_group']} /* Services */,
\t\t\t\t{IDS['utilities_group']} /* Utilities */,
\t\t\t\t{IDS['viewmodels_group']} /* ViewModels */,
\t\t\t\t{IDS['views_group']} /* Views */,
\t\t\t);
\t\t\tpath = Alset;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['config_group']} /* Config */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_id('Alset/Config/AppSecrets.swift')} /* AppSecrets.swift */,
\t\t\t\t{IDS['secrets_xcconfig_ref']} /* Secrets.xcconfig */,
\t\t\t\t{IDS['secrets_example_ref']} /* Secrets.xcconfig.example */,
\t\t\t);
\t\t\tpath = Config;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['models_group']} /* Models */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_id('Alset/Models/TeslaVehicleModels.swift')} /* TeslaVehicleModels.swift */,
\t\t\t);
\t\t\tpath = Models;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['services_group']} /* Services */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_id('Alset/Services/SupabaseAuthService.swift')} /* SupabaseAuthService.swift */,
\t\t\t\t{file_ref_id('Alset/Services/TeslaAuthRepository.swift')} /* TeslaAuthRepository.swift */,
\t\t\t\t{file_ref_id('Alset/Services/TeslaNetworkManager.swift')} /* TeslaNetworkManager.swift */,
\t\t\t\t{file_ref_id('Alset/Services/TeslaOAuthService.swift')} /* TeslaOAuthService.swift */,
\t\t\t);
\t\t\tpath = Services;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['utilities_group']} /* Utilities */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_id('Alset/Utilities/PKCE.swift')} /* PKCE.swift */,
\t\t\t);
\t\t\tpath = Utilities;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['viewmodels_group']} /* ViewModels */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_id('Alset/ViewModels/AppViewModel.swift')} /* AppViewModel.swift */,
\t\t\t);
\t\t\tpath = ViewModels;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDS['views_group']} /* Views */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_id('Alset/Views/LoginView.swift')} /* LoginView.swift */,
\t\t\t\t{file_ref_id('Alset/Views/RootView.swift')} /* RootView.swift */,
\t\t\t\t{file_ref_id('Alset/Views/TeslaConnectView.swift')} /* TeslaConnectView.swift */,
\t\t\t\t{file_ref_id('Alset/Views/VehicleDashboardView.swift')} /* VehicleDashboardView.swift */,
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{IDS['target']} /* {PRODUCT_NAME} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {IDS['target_config_list']} /* Build configuration list for PBXNativeTarget "{PRODUCT_NAME}" */;
\t\t\tbuildPhases = (
\t\t\t\t{IDS['sources_phase']} /* Sources */,
\t\t\t\t{IDS['frameworks_phase']} /* Frameworks */,
\t\t\t\t{IDS['resources_phase']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {PRODUCT_NAME};
\t\t\tproductName = {PRODUCT_NAME};
\t\t\tproductReference = {IDS['product_ref']} /* {PRODUCT_NAME}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{IDS['project']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{IDS['target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {IDS['project_config_list']} /* Build configuration list for PBXProject "{PRODUCT_NAME}" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {IDS['main_group']};
\t\t\tproductRefGroup = {IDS['products_group']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{IDS['target']} /* {PRODUCT_NAME} */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{IDS['resources_phase']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{IDS['sources_phase']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(sources_entries)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{IDS['debug_project']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = {IDS['secrets_xcconfig_ref']} /* Secrets.xcconfig */;
\t\t\tbuildSettings = {{
{debug_project}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{IDS['release_project']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = {IDS['secrets_xcconfig_ref']} /* Secrets.xcconfig */;
\t\t\tbuildSettings = {{
{release_project}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{IDS['debug_target']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_target}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{IDS['release_target']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_target}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{IDS['project_config_list']} /* Build configuration list for PBXProject "{PRODUCT_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{IDS['debug_project']} /* Debug */,
\t\t\t\t{IDS['release_project']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{IDS['target_config_list']} /* Build configuration list for PBXNativeTarget "{PRODUCT_NAME}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{IDS['debug_target']} /* Debug */,
\t\t\t\t{IDS['release_target']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {IDS['project']} /* Project object */;
}}
"""


def workspace_content() -> str:
    return """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""


def scheme_content() -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{IDS['target']}"
               BuildableName = "{PRODUCT_NAME}.app"
               BlueprintName = "{PRODUCT_NAME}"
               ReferencedContainer = "container:Alset.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{IDS['target']}"
            BuildableName = "{PRODUCT_NAME}.app"
            BlueprintName = "{PRODUCT_NAME}"
            ReferencedContainer = "container:Alset.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{IDS['target']}"
            BuildableName = "{PRODUCT_NAME}.app"
            BlueprintName = "{PRODUCT_NAME}"
            ReferencedContainer = "container:Alset.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


def write_project() -> list[Path]:
    ensure_secrets_xcconfig()

    PROJECT_DIR.mkdir(parents=True, exist_ok=True)
    SCHEME_DIR.mkdir(parents=True, exist_ok=True)
    WORKSPACE_DIR.mkdir(parents=True, exist_ok=True)

    created = [
        PROJECT_DIR / "project.pbxproj",
        WORKSPACE_DIR / "contents.xcworkspacedata",
        SCHEME_DIR / f"{PRODUCT_NAME}.xcscheme",
    ]
    created[0].write_text(pbxproj_content(), encoding="utf-8")
    created[1].write_text(workspace_content(), encoding="utf-8")
    created[2].write_text(scheme_content(), encoding="utf-8")
    return created


def main() -> None:
    paths = write_project()
    print(f"Generated {PROJECT_DIR.relative_to(ROOT)}/")
    for path in paths:
        print(f"  {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
