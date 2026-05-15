pipeline {
    agent {
        docker {
            image 'gcr.io/bazel-public/bazel:latest'
        }
    }
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    stages {
        stage('Build') {
            steps {
                // just for demo
                withCredentials([usernamePassword(
                    credentialsId: 'github-pat',         // matches the ID in Jenkins credentials store                                                                                         
                    usernameVariable: 'DEPLOY_USER',     // Jenkins sets $DEPLOY_USER = stored username                                                                                         
                    passwordVariable: 'DEPLOY_PASS'      // Jenkins sets $DEPLOY_PASS = stored password                                                                                         
                )]) {                                                                                                                                                                           
                    sh 'echo "User is $DEPLOY_USER"'                                                                                                                             
                    sh 'echo "PAT is $DEPLOY_PASS"'                                                                                                 
                }   

                sh 'bazel build --config=ci //cpp-task:main //go-task:go_bin //java-task:main'
            }
        }
        stage('Test') {
            steps {
                sh 'bazel test --config=ci //...'
            }
        }
        stage('Deploy') {
            steps {
                sh 'mkdir -p artifacts'
                sh 'install bazel-bin/cpp-task/main artifacts/cpp-main'
                sh 'install bazel-bin/go-task/go_bin_/go_bin artifacts/go-bin'
                sh 'install bazel-bin/java-task/main.jar artifacts/main.jar'

                echo '=== Build Artifacts ==='

                sh 'ls -la bazel-bin/cpp-task/main'
                sh 'ls -la bazel-bin/go-task/go_bin_/go_bin'
                sh 'ls -la bazel-bin/java-task/main.jar'
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
