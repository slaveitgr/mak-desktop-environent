#include "lone_modifier_tap.h"
#include <cassert>

using cutefish::input::LoneModifierTap;
int main() {
    LoneModifierTap tap;
    auto key = [&](unsigned code, bool down, bool blocked = false) {
        return tap.key(code, down, code == 125 || code == 126, blocked);
    };
    for (auto super : {125u, 126u}) {
        assert(!key(super, true)); assert(!key(super, true));
        assert(key(super, false)); assert(!key(super, false));
        assert(!key(super, true)); assert(!key(30, true));
        assert(!key(30, false)); assert(!key(super, false));
        assert(!key(super, true)); assert(!key(30, true));
        assert(!key(super, false)); assert(!key(30, false));
        assert(!key(42, true)); assert(!key(super, true));
        assert(!key(42, false)); assert(!key(super, false));
        assert(!key(super, true)); tap.cancel(); assert(!key(super, false));
        assert(!key(super, true, true)); assert(!key(super, false));
        assert(!key(super, true)); assert(!key(super, false, true));
    }
    assert(!key(125, true)); assert(!key(126, true));
    assert(!key(125, false)); assert(!key(126, false));
    assert(!key(30, true)); assert(!key(30, false));
    assert(!key(125, true)); assert(key(125, false));
}
