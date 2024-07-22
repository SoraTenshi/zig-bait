#include <iostream>
#include <string>

#ifdef _WIN32
#define DLLEXPORT __declspec(dllexport)
#define WEAK __declspec(selectany)
#define ALIAS(name) __pragma(comment(linker, "/alternatename:" #name "=iat_test_func_dummy"))
#else
#define DLLEXPORT __attribute((visibility("default")))
#define WEAK __attribute((weak))
#define ALIAS(name) __attribute__((alias("iat_test_func_dummy")))
#endif

// This should be in the IAT, so a valuable candidate for testing :3
using VoidFnPtr = void(*)();
extern "C" WEAK VoidFnPtr iat_test_func;

extern "C" void iat_test_func_dummy() {
    iat_test_func = (VoidFnPtr)0x0;
}
ALIAS(iat_test_func);

class Base {
  public:
    virtual void func0() = 0;
    virtual char *func1() = 0;
};

class Derived: public Base {
  private:
    std::string keep_alive = "";
  public:
    bool func0_call = false;
    void func0() override {
      func0_call = true;
      std::cout << "Hello, i am func0 in C++\n";
    }

    bool func1_call = false;
    char *func1() override {
      func1_call = true;
      this->keep_alive = "I AM ALIVE IN ((CPP))\n";
      return const_cast<char*>(this->keep_alive.c_str());
    }
};

Base *vtable_instance = nullptr;
extern "C" DLLEXPORT Base *GetVtableInstance() {
  return vtable_instance;
}

auto main() -> int {
  vtable_instance = new Derived{};

  std::cout << "Start to call vtable functions:\n";
  std::cout << "==================================\n";
  std::cout << "Now time for **func1**:\n";
  std::cout << "Normal output: Hello, i am func0 in C++\n";
  vtable_instance->func0();
  std::cout << "=================================\n";
  std::cout << "Now time for **func1**:\n";
  std::cout << "Normal output: I AM ALIVE IN ((CPP))\n";
  vtable_instance->func1();
  std::cout << "=================================\n";

  auto as_der = dynamic_cast<Derived*>(vtable_instance);
  // if all hooks were in place -> result of **both** are 0, therefore exit code: 0 => success.
  const auto ret = as_der->func0_call || as_der->func1_call;
  as_der = nullptr;
  delete dynamic_cast<Derived*>(vtable_instance);

  return static_cast<int>(ret);
}
