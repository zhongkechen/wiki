/*Write a program to implement a queue using two stacks.*/

#include <stack>
using namespace std;

template<class T>
class my_queue {
public:
    typedef T value_type;
    typedef size_t size_type;

    bool empty() const {
        return s1.empty() && s2.empty();
    }
    size_type size() const {
        return s1.size() + s2.size();
    }

    value_type& front() {
        if(s2.empty())
            transfer();
        return s2.top();
    }
    const value_type& front() const{
        if(s2.empty())
            transfer();
        return s2.top();
    }
    value_type& back() {
        if(s1.empty());
            transfer_back();
        return s1.top();
    }
    const value_type& back() const {
        if(s1.empty());
            transfer_back();
        return s1.top();
    }
    void push(const value_type&t) {
        s1.push(t);
    }
    void pop() {
        if(s2.empty())
            transfer();
        s2.pop();
    }

private:
    void transfer() const{
        while(!s1.empty()) {
            s2.push(s1.top());
            s1.pop();
        }
    }
    void transfer_back() const{
        while(!s2.empty()) {
            s1.push(s2.top());
            s2.pop();
        }
    }
    mutable stack<value_type> s1;
    mutable stack<value_type> s2;
};


int main() {
    my_queue<int> q;

}
