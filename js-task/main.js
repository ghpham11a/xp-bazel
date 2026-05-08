const subtaskA = require("./subtask-a/subtask_a");
const subtaskB = require("./subtask-b/subtask_b");

function getMessage() {
    return "Task complete from JavaScript";
}

if (require.main === module) {
    console.log(subtaskA.getMessage());
    console.log(subtaskB.getMessage());
    console.log(getMessage());
}

module.exports = { getMessage };
