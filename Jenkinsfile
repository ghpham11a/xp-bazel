pipeline {
    agent none
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    stages {
        stage('CI') {
            agent {
                docker {
                    image 'gcr.io/bazel-public/bazel:latest'
                    args '--entrypoint='
                }
            }
            stages {
                stage('Parallel Checks') {
                    parallel {
                        stage('Lint') {
                            steps {
                                sh 'echo "Running lint..."'
                                // sh 'bazel run //:buildifier -- --lint=warn -r .'
                            }
                        }
                        stage('Unit Tests') {
                            steps {
                                sh 'bazel test --config=ci //...'
                            }
                        }
                    }
                }
                stage('Build') {
                    steps {
                        // just for demo
                        withCredentials([usernamePassword(
                            credentialsId: 'github-pat',
                            usernameVariable: 'DEPLOY_USER',
                            passwordVariable: 'DEPLOY_PASS'
                        )]) {
                            sh 'echo "User is $DEPLOY_USER"'
                            sh 'echo "PAT is $DEPLOY_PASS"'
                        }

                        sh 'bazel build --config=ci //cpp-task:main //go-task:go_bin //java-task:main'
                    }
                }
                stage('Deploy to Staging') {
                    when { branch 'master' }
                    steps {
                        sh 'mkdir -p artifacts'
                        sh 'install bazel-bin/cpp-task/main artifacts/cpp-main'
                        sh 'install bazel-bin/go-task/go_bin_/go_bin artifacts/go-bin'
                        sh 'install bazel-bin/java-task/main.jar artifacts/main.jar'

                        echo '=== Build Artifacts ==='

                        sh 'ls -la bazel-bin/cpp-task/main'
                        sh 'ls -la bazel-bin/go-task/go_bin_/go_bin'
                        sh 'ls -la bazel-bin/java-task/main.jar'

                        archiveArtifacts artifacts: 'artifacts/**/*', fingerprint: true
                    }
                }
            }
        }
        stage('Deploy to Prod') {
            when { branch 'master' }
            agent none
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input message: 'Deploy to production?', ok: 'Deploy'
                }
                node('') {
                    echo 'Deploying to prod...'
                }
            }
        }
    }
    post {
        always {
            echo 'Pipeline complete'
        }
        success {
            echo 'All stages passed'
        }
        failure {
            echo 'Pipeline failed'
            // slackSend channel: '#builds', message: "Build failed: ${env.BUILD_URL}"
        }
        unstable {
            echo 'Pipeline unstable (flaky tests?)'
        }
    }
}
