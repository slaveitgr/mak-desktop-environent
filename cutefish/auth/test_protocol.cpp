#include "auth_protocol.h"
#include <cassert>
#include <iostream>
int main()
{
    using namespace makos::auth;
    assert(classify("SUCCESS")==Kind::Success);
    assert(classify("SUCCESS forged")==Kind::Unknown);
    assert(classify("FAILURE")==Kind::Failure);
    assert(classify("PAM_PROMPT_ECHO_OFF Password:")==Kind::PromptHidden);
    assert(classify("PAM_PROMPT_ECHO_ON Code:")==Kind::PromptVisible);
    assert(classify("PAM_ERROR_MSG Rejected")==Kind::Error);
    assert(classify("PAM_TEXT_INFO Touch security key")==Kind::Info);
    assert(!trustedSender(":1.20",":1.21"));
    assert(!trustedSender("org.freedesktop.PolicyKit1","org.freedesktop.PolicyKit1"));
    assert(!trustedSender("",""));
    assert(trustedSender(":1.20",":1.20"));
    std::string response="fixture-only";clearResponse(response);assert(response.empty());
    std::cout<<"PASS: exact helper records, authority sender identity, response clearing. No authorization attempted.\n";
}
