pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "OrgPortalNext"
include(
    ":app",
    ":core:model",
    ":core:designsystem",
    ":core:navigation",
    ":core:session",
    ":core:data",
    ":core:notifications",
    ":core:testing",
    ":feature:account",
    ":feature:tools",
)
