// Root build file for the Whatsapp_Clone project.
// The actual Android build logic is in the 'android' directory.
// This file exists to satisfy Gradle when run from the root directory.

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
