//
//  newTabScript.js
//  iQ3ConnectXRViewer
//
//  Created by IQ3 on 8/8/25.
//  Copyright © 2025 iQ3Connect. All rights reserved.
//

(function() {
    const originalOpen = window.open;
    window.open = function(url, target, options) {
        if (typeof webkit !== 'undefined' && webkit.messageHandlers) {
            if (url && webkit.messageHandlers.openInNewTab) {
                // Ask the native app to open this URL in a NEW tab.
                webkit.messageHandlers.openInNewTab.postMessage({ url: String(url) });
            }
            return {
                closed: false,
                close: function() {},
                focus: function() {},
                blur: function() {},
                location: { href: url }
            };
        }
        return originalOpen.call(this, url, target, options);
    };

    function setupLinkOverrides() {
        document.addEventListener('click', function(event) {
            const link = event.target.closest('a');
            if (!link || !link.href) return;
            
            const shouldOverride = (
                link.target === '_blank' ||
                link.target === '_new' ||
                event.ctrlKey ||
                event.metaKey ||
                event.button === 1
            );
            
            if (shouldOverride && typeof webkit !== 'undefined' && webkit.messageHandlers && webkit.messageHandlers.openInNewTab) {
                // Open target=_blank / cmd-click / middle-click links in a NEW native tab.
                event.preventDefault();
                webkit.messageHandlers.openInNewTab.postMessage({ url: String(link.href) });
                return false;
            }
        }, true);

        document.addEventListener('submit', function(event) {
            const form = event.target;
            if (form.target === '_blank' && typeof webkit !== 'undefined' && webkit.messageHandlers) {
                form.target = '_self';
            }
        }, true);
    }
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setupLinkOverrides);
    } else {
        setupLinkOverrides();
    }
})();
