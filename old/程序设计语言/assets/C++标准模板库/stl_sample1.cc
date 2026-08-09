/* Write a program to print a histogram of the frequencies of different
characters in its input. */

#include <vector>
#include <iostream>
#include <cstdlib>
#include <cctype>
using namespace std;

int main() {
    vector<int> freq(256, 0);
    int c;
    while((c = cin.get()) != EOF)
        freq[c] ++;
    for(int i = 0; i < freq.size(); i++) {
        if(freq[i] != 0) {
            cout << i << '\t'<< (isprint(i)?(char)i:' ') << '\t'<< freq[i] << '\t';
            for(int j = 0; j < freq[i]; j++)
                cout << '=';
            cout << endl;
        }
    }
    system("pause");
}
