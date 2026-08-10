/* Write the program tail, which prints the last n lines of its input. By
default, n is set to 10, let us say, but it can be changed by an optional
argument so that
   tail -n
prints the last n lines. The program should behave rationally no matter how
unreasonable the input or the value of n. Write the program so it makes the best
 use of available storage. */

#include <queue>
#include <iostream>
#include <sstream>

using namespace std;

int main(int argc, char *argv[]) {
    int n = 10;
    if(argc == 2) {
        istringstream is(argv[1]+1);
        is >> n;
    } else if(argc > 2) {
        printf("Usage: %s -n\n", argv[0]);
    }
    queue<string> tails;
    string line;
    while(getline(cin, line)) {
        tails.push(line);
        if(tails.size() > n)
            tails.pop();
    }
    while(!tails.empty()) {
        cout << tails.front() << endl;
        tails.pop();
    }
    system("pause");
}
