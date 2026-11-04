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

// Fix: camera-core 1.5.x referencia androidx.concurrent en anotaciones de
// tipo; javac necesita el jar en scope de compilación (no solo runtime).
// Sin esto, :camera_android_camerax:compileDebugJavaWithJavac falla con
// "class file for androidx.concurrent.futures.CallbackToFutureAdapter not found".
// Se usa projectsEvaluated (los subproyectos ya están evaluados por
// evaluationDependsOn, por lo que afterEvaluate fallaría).
gradle.projectsEvaluated {
    subprojects.forEach { p ->
        if (p.name.startsWith("camera_android")) {
            try {
                p.dependencies.add(
                    "implementation",
                    "androidx.concurrent:concurrent-futures:1.1.0",
                )
            } catch (e: Exception) {
                p.logger.warn("No se pudo agregar concurrent-futures a ${p.name}: ${e.message}")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
