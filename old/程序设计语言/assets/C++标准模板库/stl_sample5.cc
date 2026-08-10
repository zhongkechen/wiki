/*编序为1，2，．．．n的n个人按顺时针方向围坐一圈，每人持有一个密码（正整数），
一开始人选一个整数作为报数上限m,从第一个人开始按顺时针方向从自 1开始顺序报数,
报到m时停止报数.报m的人出列,将他的密码作为新的m值,从他的顺时针方向上的下一个人
开始从1报数,如此下去,知道所有人全部出列为止,设计一个程序求出出列顺序.*/

/*
first number is m
and the following are numbers everyone hold
terminated by EOF
*/

#include <list>
#include <algorithm>
#include <iostream>
#include <iterator>
using namespace std;

int main() {
    int m;
    list<int> numbers;
    cin >> m;
    copy(istream_iterator<int>(cin), istream_iterator<int>(), back_inserter< list<int> >(numbers));
//    copy(numbers.begin(), numbers.end(), ostream_iterator<int>(cout, "\t"));
    list<int>::iterator iter = numbers.begin();
    while(!numbers.empty()) {
        for(int i = 1; i < m; i++) {
            iter++;
            if(iter == numbers.end())
                iter = numbers.begin();
        }
        list<int>::iterator select = iter;
        iter++;
        if(iter == numbers.end())
            iter = numbers.begin();
        m = *select;
        numbers.erase(select);
    }
    cout << m;
    system("pause");
}
