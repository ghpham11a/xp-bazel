from colorama import Fore, Style
from subtask_a.subtask_a import get_message as get_message_a
from subtask_b.subtask_b import get_message as get_message_b


def get_message():
    return "Task complete from Python"


if __name__ == "__main__":
    print(Fore.GREEN + get_message_a() + Style.RESET_ALL)
    print(Fore.GREEN + get_message_b() + Style.RESET_ALL)
    print(Fore.GREEN + get_message() + Style.RESET_ALL)
