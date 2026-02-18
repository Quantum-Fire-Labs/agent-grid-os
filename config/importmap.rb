# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "xterm", to: "https://cdn.jsdelivr.net/npm/xterm@5.3.0/+esm"
pin "xterm-addon-fit", to: "https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/+esm"
pin_all_from "app/javascript/controllers", under: "controllers"
