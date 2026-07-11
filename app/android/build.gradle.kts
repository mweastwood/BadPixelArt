allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val jvmTargetProvider = project.provider {
            val android = project.extensions.findByName("android")
            val targetCompat = when (android) {
                is com.android.build.gradle.LibraryExtension -> android.compileOptions.targetCompatibility
                is com.android.build.gradle.AppExtension -> android.compileOptions.targetCompatibility
                else -> null
            }
            val targetStr = targetCompat?.toString() ?: "1.8"
            when {
                targetStr.contains("1.8") || targetStr.equals("8") -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                targetStr.contains("11") -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                targetStr.contains("17") -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                targetStr.contains("21") -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
            }
        }
        compilerOptions {
            jvmTarget.set(jvmTargetProvider)
        }
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
