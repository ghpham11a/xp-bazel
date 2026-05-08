const assert = require("assert");
const { getMessage } = require("./main");

assert.strictEqual(getMessage(), "Task complete from JavaScript");
console.log("PASSED: Task complete from JavaScript");
