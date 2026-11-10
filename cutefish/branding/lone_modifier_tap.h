#pragma once
#include <cstdint>
#include <set>

namespace cutefish::input {
// Observes physical keys only. It never consumes a press, release or combination.
class LoneModifierTap {
public:
    bool key(uint32_t code, bool pressed, bool modifier, bool blocked) {
        if (blocked) cancel();
        if (pressed) {
            if (!m_down.insert(code).second) return false; // hardware repeat
            if (m_down.size() == 1 && modifier && !blocked) m_candidate = code;
            else cancel();
            return false;
        }
        const bool known = m_down.erase(code) != 0;
        const bool trigger = known && m_candidate && m_candidate == code && !blocked;
        if (m_candidate == code) cancel();
        return trigger;
    }
    void cancel() { m_candidate = 0; }
private:
    std::set<uint32_t> m_down;
    uint32_t m_candidate = 0;
};
} // namespace cutefish::input
