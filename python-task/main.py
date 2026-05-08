from subtask_a.subtask_a import get_message as get_message_a
from subtask_b.subtask_b import get_message as get_message_b


def get_message():
    return "Task complete from Python"


if __name__ == "__main__":
    print(get_message_a())
    print(get_message_b())
    print(get_message())
