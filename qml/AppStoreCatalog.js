.pragma library

var categories = ["Business", "Developer Tools", "Education", "Entertainment", "Finance", "Games", "Graphics & Design", "Health & Fitness", "Lifestyle", "Medical", "Music", "News", "Photo & Video", "Productivity", "Reference", "Safari Extensions", "Social Networking", "Sports", "Travel", "Utilities", "Weather"];
var descriptions = {
    finder: ["Utilities", "Browse and organise your files", "Browse local folders, search for files and manage them with copy, move, rename and Trash operations."],
    settings: ["Utilities", "Make makOS your own", "Change the desktop appearance and configure the system controls supported on your Linux session."],
    safari: ["Utilities", "Your window to the web", "Browse with tabs and bookmarks, save downloads and use separate private windows. This makOS browser currently uses QtWebEngine."],
    notes: ["Productivity", "A place for your ideas", "Write and search local notes. Changes save automatically; pin important notes and restore deleted ones."],
    reminders: ["Productivity", "Keep track of what is next", "Create local reminders, mark them complete and organise tasks by their scheduled date."],
    calendar: ["Productivity", "Your plans at a glance", "Browse the month and create, edit or remove events in your local calendar."],
    contacts: ["Productivity", "Everyone, together", "Create, edit and search local contact cards, with favourites available to the other makOS contact views."],
    messages: ["Social Networking", "Keep your drafts together", "Write and organise local message drafts. Messaging accounts and delivery are not connected."],
    mail: ["Productivity", "Compose your next message", "Compose local email drafts and export MIME messages. Sending, receiving and mail accounts are not connected."],
    facetime: ["Social Networking", "Your video-call contacts", "Browse local contacts. Video calling and Apple account services are not connected."],
    phone: ["Social Networking", "Contacts and a familiar keypad", "Find a local contact, enter a number and copy it. Calling services are not connected."],
    maps: ["Travel", "Explore with OpenStreetMap", "Search for places and browse the OpenStreetMap web map. Offline maps and native routing are not included."],
    photos: ["Photo & Video", "Your pictures, in one place", "Import and browse local photographs and mark favourites. Cloud libraries and advanced editing are not included."],
    music: ["Music", "Listen to your music files", "Import local audio into your library and play it with the makOS music controls."],
    photobooth: ["Photo & Video", "A moment, captured", "Take pictures with a supported camera, use the photo-strip workflow and save them locally."],
    calculator: ["Utilities", "Everyday and scientific calculations", "Evaluate arithmetic and scientific expressions and revisit your calculation history."],
    terminal: ["Developer Tools", "A real local shell", "Work with a local terminal session, enter commands, paste text and resize the terminal."],
    chess: ["Games", "Your next move", "Play chess with legal move checking, promotion, castling, en passant and move history."],
    games: ["Games", "Your game library", "Browse the included games and open Chess."]
};
function metadata(app) {
    var info = descriptions[app.id] || ["Utilities", "Included with makOS", "An application included with this desktop."];
    return {id:app.id, name:app.name, image:app.image || app.id + ".png", category:info[0], subtitle:info[1], description:info[2]};
}
function sectionMatches(app, section) {
    if (section === "Create") return ["Photo & Video", "Music", "Graphics & Design"].indexOf(app.category) >= 0;
    if (section === "Work") return ["Productivity", "Business"].indexOf(app.category) >= 0;
    if (section === "Play") return app.category === "Games";
    if (section === "Develop") return app.category === "Developer Tools";
    return true;
}
