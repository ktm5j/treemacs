from subprocess import Popen, PIPE, DEVNULL
import sys

FILE = sys.argv[1]
PREV_STATE = sys.argv[2]
PARENTS = [p for p in sys.argv[3:]]

IS_IGNORED_CMD = 'git check-ignore '
IS_TRACKED_CMD = 'git ls-files --error-unmatch '
IS_CHANGED_CMD = 'git diff --exit-code '

def main():
    ignored_proc = Popen(IS_IGNORED_CMD + FILE, shell=True, stdout=PIPE, stderr=DEVNULL)
    tracked_proc = Popen(IS_TRACKED_CMD + FILE, shell=True, stdout=PIPE, stderr=DEVNULL)
    changed_proc = Popen(IS_CHANGED_CMD + FILE, shell=True, stdout=PIPE, stderr=DEVNULL)

    new_state = "0"

    if ignored_proc.wait() == 0:
        new_state = "!"
    elif tracked_proc.wait() == 1:
        new_state = "?"
    elif changed_proc.wait() == 1:
        new_state = "M"

    if PREV_STATE == new_state:
        sys.exit(2)

    proc_list = []

    for p in PARENTS:
        add_git_processes(proc_list, p)

    result_list = [(FILE, new_state)]

    i = 0
    l = len(proc_list)
    propagate_state = None
    while i < l:
        path, ignore_proc, tracked_proc, changed_proc = proc_list[i]
        if ignore_proc.wait() == 0:
            propagate_state = "!"
            result_list.append((path, propagate_state))
            break
        elif tracked_proc.wait() == 1:
            propagate_state = "?"
            result_list.append((path, propagate_state))
            break
        elif changed_proc.wait() == 1:
            result_list.append((path, "M"))
        else:
            result_list.append((path, "0"))
        i += 1

    if propagate_state:
        i += 1
        while i < l:
            result_list.append((proc_list[i][0], propagate_state))
            i += 1

    elisp_conses = "".join([f'("{path}" . "{state}")' for path,state in result_list])
    elisp_alist = f"({elisp_conses})"
    print(elisp_alist)

def add_git_processes(status_listings, path):
    ignored_proc = Popen(IS_IGNORED_CMD + path, shell=True, stdout=PIPE, stderr=DEVNULL)
    tracked_proc = Popen(IS_TRACKED_CMD + path, shell=True, stdout=PIPE, stderr=DEVNULL)
    changed_proc = Popen(IS_CHANGED_CMD + path, shell=True, stdout=PIPE, stderr=DEVNULL)

    status_listings.append((path, ignored_proc, tracked_proc, changed_proc))

main()
