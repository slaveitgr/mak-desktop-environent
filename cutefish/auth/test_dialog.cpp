// Headless UI only: no listener, helper, polkit daemon, or PAM conversation.
#include "dialog.h"
#include "ui/application.h"
#include "ui/keys.h"
#include "ui/test_input.h"
#include "ui/text_field.h"
#include "ui/window.h"
#include <cassert>
#include <iostream>
#include <vector>
using namespace cutefish::ui;
static void fields(View* view,std::vector<TextField*>& result)
{
    if (auto* field=dynamic_cast<TextField*>(view)) result.push_back(field);
    for (const auto& child:view->children()) fields(child.get(),result);
}
int main(int argc,char** argv)
{
    assert(argc==3);
    Application app(argc,argv,Application::Platform::Headless);
    Dialog dialog("Fixture Settings wants to make a change.","fixture-admin",argv[1]);
    int submitted=0;bool cancelled=false;
    dialog.onAccepted=[&]{assert(dialog.password()=="fixture-only");++submitted;};
    dialog.onCancel=[&]{cancelled=true;};
    dialog.show();dialog.setRequest("",false);
    auto* window=dialog.window();auto image=window->grab();
    assert(!image.isNull()&&window->size().width==443&&window->size().height>180);
    assert(image.savePng(argv[2]));
    std::vector<TextField*> inputs;fields(window->contentView(),inputs);
    assert(inputs.size()==2&&inputs[0]->isReadOnly()&&inputs[1]->echoMode()==TextField::EchoMode::Password);
    TestInput::setKeyboardFocus(*window,true);inputs[1]->setFocus();
    TestInput::typeKey(*window,key::Return);assert(submitted==0);
    TestInput::typeText(*window,"fixture-only");TestInput::typeKey(*window,key::Return);
    assert(submitted==1&&dialog.password().empty()&&inputs[1]->text().empty()&&!inputs[1]->isEnabled());
    dialog.authenticationFailure();assert(inputs[1]->isEnabled()&&inputs[1]->text().empty());
    dialog.setRequest("Verification code:",true);assert(inputs[1]->echoMode()==TextField::EchoMode::Normal);
    dialog.setRequest("",false);assert(inputs[1]->echoMode()==TextField::EchoMode::Password);
    TestInput::typeKey(*window,key::Escape);assert(cancelled);
    dialog.hide();assert(dialog.password().empty()&&inputs[1]->text().empty());
    std::cout<<"PASS: headless real Toolkit dialog, protected field, Enter/Escape, clear-on-submit/retry/cancel. No authorization attempted.\n";
}
