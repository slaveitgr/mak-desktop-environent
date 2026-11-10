// Fixture helper processes only; no polkit daemon, PAM, account, or system bus.
#include "authsession.h"
#include "base/event_loop.h"
#include <cassert>
#include <chrono>
#include <fstream>
#include <iostream>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
using namespace cutefish::base;
using namespace std::chrono_literals;
int main()
{
    char directory[]="/tmp/makos-auth-test-XXXXXX";
    assert(mkdtemp(directory));
    const std::string helper=std::string(directory)+"/helper";
    const std::string socket=std::string(directory)+"/no-socket";
    for (const auto& [ending, expected] : {std::pair{"SUCCESS\nexit 0",true}, {"FAILURE\nexit 0",false}, {"SUCCESS forged\nexit 0",false}, {"SUCCESS\nexit 3",false}}) {
        std::ofstream script(helper);
        const std::string body(ending);
        const auto newline=body.find('\n');
        script<<"#!/bin/sh\nIFS= read -r cookie\nprintf 'PAM_PROMPT_ECHO_OFF Password:\\n'\nIFS= read -r response\n[ \"$response\" = fixture-only ] || exit 2\nprintf '"<<body.substr(0,newline)<<"\\n'\n"<<body.substr(newline+1)<<"\n";
        script.close();assert(chmod(helper.c_str(),0700)==0);
        EventLoop loop;AuthSession session;bool completed=false;bool requested=false;
        AuthSession::setHelperForTesting(helper,socket);
        session.onRequest=[&](const std::string& prompt,bool echo){assert(prompt=="Password:"&&!echo);requested=true;session.respond("fixture-only");};
        session.onCompleted=[&](bool success){assert(success==expected);completed=true;loop.quit();};
        loop.startTimer(3s,false,[&]{loop.quit(2);});
        session.start("fixture-user","fixture-cookie");
        assert(loop.run()==0&&completed&&requested);
    }
    unlink(helper.c_str());rmdir(directory);
    std::cout<<"PASS: real fixture-helper pipes, PAM prompt, exact success/failure and nonzero-exit rejection. No authorization attempted.\n";
}
