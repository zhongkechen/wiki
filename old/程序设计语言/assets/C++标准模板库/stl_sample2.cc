/* Write a program to print a histogram of the lengths of words in its input. It
 is easy to draw the histogram with the bars horizontal; a vertical orientation
 is more challenging.*/

#include <vector>
#include <iostream>
#include <algorithm>
#include <cstdlib>
#include <iterator>

using namespace std;
#include <vector>
#include <iostream>
#include <cstdlib>
#include <cctype>
using namespace std;

int main() {
    vector<int> freq;
    string word;
    while(cin >> word) {
        if(word.length()+1 > freq.size())
            freq.resize(word.length()+1);
        freq[word.length()] ++;
    }
    for(int i = 0; i < freq.size(); i++) {
        if(freq[i] != 0) {
            cout << i << '\t'<< freq[i] << '\t';
            for(int j = 0; j < freq[i]; j++)
                cout << '=';
            cout << endl;
        }
    }
    system("pause");
}
