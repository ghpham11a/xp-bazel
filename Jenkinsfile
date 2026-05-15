pipeline {
    agent any
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    stages {
        stage('Build') {
            steps {
                bazel build --config=ci //cpp-task:main //go-task:go_bin //java-task:main
            }
        }
        stage('Test') {
            steps {
                bazel test --config=ci //...
            }
        }
        stage('Deploy') {
            steps {
                mkdir -p artifacts
                cp bazel-bin/cpp-task/main artifacts/cpp-main
                cp bazel-bin/go-task/go_bin_/go_bin artifacts/go-bin
                cp bazel-bin/java-task/main.jar artifacts/main.jar

                echo '=== Build Artifacts ==='

                ls -la bazel-bin/cpp-task/main
                ls -la bazel-bin/go-task/go_bin_/go_bin
                ls -la bazel-bin/java-task/main.jar 
            }
        }
    }
    post {
        success {
            archiveArtifacts artifacts: 'artifacts/**/*', fingerprint: true
        }
        failure {
            // slack/email notification
            echo 'failure'
        }
    }
}