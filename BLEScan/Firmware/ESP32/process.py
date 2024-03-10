import re
from collections import defaultdict


def process_log_file(filename):
    unique_packets_per_run = []
    with open(filename, 'r') as file:
        packets = defaultdict(int)
        run_count = None

        for line in file:
            if line.startswith("Scan parameters set"):
                packets = defaultdict(int)  # Reset for new run
            elif line.startswith("Run Count:"):
                run_count = int(line.split(":")[1].strip())
                print(f"Run Count: {run_count}")
                for k,v in packets.items():
                    print(f"{k}: {v}")
            elif line.startswith("Scan stopped") or line.startswith("Apple BLE packets"):
                continue
            else:
                packets[line.strip()] += 1

        for k,v in packets.items():
            print(f"{k}: {v}")

    return unique_packets_per_run


if __name__ == "__main__":
   filename = "./log.txt"  # Replace with your log file name
   results = process_log_file(filename)
