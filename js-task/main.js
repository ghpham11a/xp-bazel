function getMessage() {
    return "Task complete from JavaScript";
}

if (require.main === module) {
    console.log(getMessage());
}

module.exports = { getMessage };
