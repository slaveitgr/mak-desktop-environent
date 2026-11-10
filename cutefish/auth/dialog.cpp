// SPDX-FileCopyrightText: 2026 Reion Wong <reionwong@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause

#include "dialog.h"
#include "auth_protocol.h"

#include <cmath>

#include "ui/cell_layout.h"
#include "ui/dialog_window.h"
#include "ui/keys.h"
#include "ui/icon_image.h"
#include "ui/label.h"
#include "ui/layout.h"
#include "ui/painter.h"
#include "ui/text_field.h"
#include "ui/theme.h"
#include "ui/window.h"

using namespace cutefish::ui;

static constexpr double kWidth = 443;
static constexpr double kMargin = 20;
static constexpr double kRadius = 20;
// A drag this far from the press moves the window.
static constexpr double kDragDistance = 10;

// The rounded card the window shows, and the layout on it; any empty part of
// it drags the window, as there is no title bar.
class Dialog::Content final : public ColumnLayout
{
public:
    bool acceptsPointer() const override { return true; }

protected:
    void paint(Painter &painter) override
    {
        painter.drawSmoothRectangle(localRect(), kRadius, Theme::current().secondBackground);
    }

    void pointerPress(const PointerEvent &event) override
    {
        m_pressed = event.button == MouseButton::Left;
        m_pressPosition = event.position;
    }

    void pointerMove(const PointerEvent &event) override
    {
        if (!m_pressed || !window())
            return;
        if (std::abs(event.position.x - m_pressPosition.x) > kDragDistance
            || std::abs(event.position.y - m_pressPosition.y) > kDragDistance) {
            m_pressed = false;
            window()->startMove();
        }
    }

    void pointerRelease(const PointerEvent &) override { m_pressed = false; }

private:
    bool m_pressed = false;
    PointF m_pressPosition;
};

Dialog::Dialog(const std::string &message, const std::string &identity, const std::string &icon)
    : m_message(message)
    , m_identity(identity)
    , m_icon(icon)
{
}

Dialog::~Dialog() { makos::auth::clearResponse(m_password); }

void Dialog::show()
{
    m_window = std::make_unique<Window>();
    m_window->setTitle("makOS — Authentication Required");
    m_window->setSkipTaskbar(true);
    // Text lays out unhinted at every scale, so lines wrap where they always did.
    m_window->setHintedTextLayout(false);
    m_window->setAlwaysOnTop(true);
    m_window->setBackgroundColor(Color {0, 0, 0, 0});
    m_window->onCloseRequested = [this] {
        if (onCancel)
            onCancel();
    };

    auto content = std::make_unique<Content>();
    content->setPadding(Margins::all(kMargin));
    content->setSpacing(12);

    auto *heading = content->addChild<RowLayout>();
    heading->setLayoutHints({.fillWidth = true});
    heading->setSpacing(10);
    auto *icon = heading->addChild<IconImage>(m_icon, 64);
    icon->setFallbackName("system-lock-screen");
    icon->setLayoutHints({.preferredWidth = 64, .preferredHeight = 64, .verticalAlignment = Alignment::Start});
    auto *texts = heading->addChild<Column>();
    texts->setSpacing(6);
    texts->setLayoutHints({.fillWidth = true});
    auto *message = texts->addChild<Label>(m_message.empty() ? "Authentication is required to make this change." : m_message);
    message->setLayoutHints({.fillWidth = true});
    message->setFontSize(13);
    message->setWeight(600);
    message->setWrap(true);
    message->setFixedLineHeight(17);
    auto *explanation = texts->addChild<Label>("Enter the password for the account below to allow this action.");
    explanation->setLayoutHints({.fillWidth = true});
    explanation->setFontSize(11);
    explanation->setWrap(true);
    explanation->setFixedLineHeight(15);

    auto *fields = content->addChild<ColumnLayout>();
    fields->setLayoutHints({.fillWidth = true});
    fields->setPadding({74, 0, 0, 0});
    fields->setSpacing(8);
    auto *identityRow = fields->addChild<RowLayout>();
    identityRow->setLayoutHints({.fillWidth = true});
    identityRow->setSpacing(8);
    auto *identityLabel = identityRow->addChild<Label>("User Name:");
    identityLabel->setFontSize(13);
    identityLabel->setLayoutHints({.preferredWidth = 76});
    identityLabel->setTextAlignment(Label::TextAlignment::Right);
    auto *identity = identityRow->addChild<TextField>(m_identity);
    identity->setReadOnly(true);
    identity->setFontSize(13);
    identity->setLayoutHints({.fillWidth = true, .preferredHeight = 26});

    auto *passwordRow = fields->addChild<RowLayout>();
    passwordRow->setLayoutHints({.fillWidth = true});
    passwordRow->setSpacing(8);
    m_promptLabel = passwordRow->addChild<Label>(m_prompt.empty() ? "Password:" : m_prompt);
    m_promptLabel->setFontSize(13);
    m_promptLabel->setWrap(true);
    m_promptLabel->setLayoutHints({.preferredWidth = 76});
    m_promptLabel->setTextAlignment(Label::TextAlignment::Right);
    m_passwordInput = passwordRow->addChild<TextField>();
    m_passwordInput->setLayoutHints({.fillWidth = true, .preferredHeight = 26});
    m_passwordInput->setFontSize(13);
    m_passwordInput->setMaximumLength(1024);
    m_passwordInput->setPlaceholder(m_prompt.empty() ? std::string("Password") : m_prompt);
    m_passwordInput->setEchoMode(m_echo ? TextField::EchoMode::Normal : TextField::EchoMode::Password);
    m_passwordInput->onAccepted = [this] {
        submit();
    };

    m_noticeLabel = content->addChild<Label>();
    m_noticeLabel->setLayoutHints({.fillWidth = true});
    m_noticeLabel->setFontSize(11);
    m_noticeLabel->setWrap(true);

    auto *buttons = content->addChild<RowLayout>();
    buttons->setSpacing(8);
    buttons->setLayoutHints({.horizontalAlignment = Alignment::End});
    auto *cancel = buttons->addChild<DialogButton>("Cancel");
    cancel->onClicked = [this] {
        if (onCancel)
            onCancel();
    };
    m_doneButton = buttons->addChild<DialogButton>("OK", true);
    m_doneButton->onClicked = [this] {
        submit();
    };

    m_window->addShortcut(NoModifier, key::Escape, [this] {
        if (onCancel)
            onCancel();
    });

    updateNotice();
    m_window->setContentView(std::move(content));
    m_window->resize({kWidth, 0});
    m_window->setFitsContentHeight(true);
    m_passwordInput->setFocus();
    m_window->show();
    m_window->activate();
}

void Dialog::hide()
{
    if (m_passwordInput) m_passwordInput->setText({});
    makos::auth::clearResponse(m_password);
    if (m_window)
        m_window->hide();
}

void Dialog::submit()
{
    if (!m_passwordInput || m_passwordInput->text().empty())
        return;

    m_doneButton->setEnabled(false);
    m_passwordInput->setEnabled(false);
    m_password = m_passwordInput->text();
    m_passwordInput->setText({});

    if (onAccepted)
        onAccepted();
    makos::auth::clearResponse(m_password);
}

void Dialog::ready()
{
    m_doneButton->setEnabled(true);
    m_passwordInput->setEnabled(true);
    m_passwordInput->setFocus();
}

void Dialog::authenticationFailure()
{
    if (!m_passwordInput)
        return;
    // Enter would otherwise send the rejected password again.
    m_passwordInput->setText({});
    ready();
}

void Dialog::setRequest(const std::string &prompt, bool echo)
{
    m_prompt = prompt;
    if (m_promptLabel) m_promptLabel->setText(prompt.empty() ? "Password:" : prompt);
    m_echo = echo;

    if (!m_passwordInput)
        return;
    m_passwordInput->setPlaceholder(m_prompt.empty() ? std::string("Password") : m_prompt);
    m_passwordInput->setEchoMode(m_echo ? TextField::EchoMode::Normal : TextField::EchoMode::Password);

    // Each further PAM question starts empty; a field still being typed in is
    // left alone.
    if (!m_passwordInput->isEnabled())
        m_passwordInput->setText({});
    ready();
}

void Dialog::setNotice(const std::string &text, bool error)
{
    if (m_notice == text && m_noticeIsError == error)
        return;

    m_notice = text;
    m_noticeIsError = error;
    updateNotice();
}

void Dialog::updateNotice()
{
    if (!m_noticeLabel)
        return;
    m_noticeLabel->setText(m_notice);
    m_noticeLabel->setVisible(!m_notice.empty());
    m_noticeLabel->setColor(m_noticeIsError ? ColorRecipe(accent::red) : ColorRecipe(ColorId::DisabledText));
}
