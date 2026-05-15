pipeline {
    agent any
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }
    stages {
        stage('Build') {
            steps {
                echo 'start build'
            }
        }
        stage('Test') {
            steps {
                echo 'start test'
            }
        }
    }
    post {
        failure {
            // slack/email notification
        }
    }
}