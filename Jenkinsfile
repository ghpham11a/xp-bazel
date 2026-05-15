pipeline {
    agent any
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
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
        stage('Deploy') {
            steps {
                echo 'start deploy'
            }
        }
    }
    post {
        failure {
            // slack/email notification
            echo 'failure'
        }
    }
}