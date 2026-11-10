// SPDX-License-Identifier: BSD-3-Clause
#pragma once
#include <string>
#include <string_view>

namespace makos::auth {
enum class Kind { PromptHidden, PromptVisible, Error, Info, Success, Failure, Unknown };
inline Kind classify(std::string_view line)
{
    if (line.starts_with("PAM_PROMPT_ECHO_OFF ")) return Kind::PromptHidden;
    if (line.starts_with("PAM_PROMPT_ECHO_ON ")) return Kind::PromptVisible;
    if (line.starts_with("PAM_ERROR_MSG ")) return Kind::Error;
    if (line.starts_with("PAM_TEXT_INFO ")) return Kind::Info;
    if (line == "SUCCESS") return Kind::Success;
    if (line == "FAILURE") return Kind::Failure;
    return Kind::Unknown;
}
inline bool trustedSender(std::string_view sender, std::string_view owner)
{
    return !owner.empty() && owner.front() == ':' && sender == owner;
}
inline void clearResponse(std::string& value)
{
    // Best-effort overwrite of our owned buffer; toolkit/allocator/kernel copies
    // cannot be promised erased. Nothing is saved, logged, or put in argv.
    volatile char* data=value.data();
    for (size_t i=0;i<value.size();++i) data[i]=0;
    value.clear();
}
}
