// select common elements
var html = document.getElementsByTagName("html")[0];
var head = document.getElementsByTagName("head")[0];

// Site base URI - proto://domain.tld unless site_uri set in <head>
var site_uri = document.location.origin.concat("/");
var site_fqdn = document.location.host;
var noSubdomain = window.location.host.split('.').slice(1).join(".");

/*
 * Boring functions
 */

function escapeRegexp(string) {
  return string.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
}

/*
 * Annotate external hyperlinks
 */

function annotate_external_links() {
    var hyperlinks = document.getElementsByTagName("a");
    var whitelist = ["localhost", site_fqdn, noSubdomain];

    for ( var i = 0; i < hyperlinks.length; i++ ) {
      for ( var x = 0; x < whitelist.length; x++ ) {
        if ( ! whitelist.includes(hyperlinks[i].host) ) {
          hyperlinks[i].classList.add("external");

          if (hyperlinks[i].href.startsWith("mailto:")) {
            hyperlinks[i].classList.add("mailto");
          }
        }
      }
    }
}


/*
 * Check GDPR / Cookie Law consent cookie
 */

function cookieConsent() {
    if ( Cookies.get("cookieplease") == "allow" ) {
        console.log("cookieConsent: allowed");
        return true;
    } else {
        console.log("cookieConsent: disallowed");
        return false;
    }
}


/* Setting: Dyslexia
 * dep: JS-Cookies, OpenDyslexic font
 */

function a11y_dyslexia_enable() {
    console.log("a11y: enable dyslexia mode");
    if (cookieConsent()) {
        Cookies.set("dyslexia", true, { secure: true });
    }

    if (["interactive", "complete"].includes(document.readyState)) {
        console.log("a11y: dyslexia class added to body.");
        document.body.classList.add("dyslexia");
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            console.log("a11y: dyslexia class waiting for DOMContentLoaded.");
            document.body.classList.add("dyslexia");
        });
    }

    // add Dyslexia font via css
    if (!(head.querySelector("link[href='".concat(site_uri, "fonts/OpenDyslexic.css']")))) {
        console.log("a11y: append dyslexia css");

        var link = document.createElement("link");
        link.setAttribute("rel", "stylesheet");
        link.setAttribute("href", site_uri.concat("fonts/OpenDyslexic.css"));
        head.appendChild(link);
    }
}

function a11y_dyslexia_disable() {
    console.log("a11y: disable dyslexia mode");
    if (cookieConsent()) {
        Cookies.set("dyslexia", false, { secure: true });
    }
    document.body.classList.remove("dyslexia");
}


/*
 * Run Immediately
 */

/* Setting: Dyslexia
 * dep: JS-Cookies, OpenDyslexic font
 */

// Enable if cookie set
if (Cookies.get("dyslexia") == "true") {
    a11y_dyslexia_enable();
}


/*
 * Document Ready
 */

window.addEventListener("DOMContentLoaded", function(event)
{
    console.log("Document ready!");

    // Annotate external links
    //annotate_external_links();

    // Setting slider
    // dep: JQuery SlideReveal
    var settings_slider = $("#settings-slider").slideReveal({
        trigger: $("#settings-toggle"),
        position: "right"
    });

    $( "#settings-slider .close" ).click(function() {
        settings_slider.slideReveal("hide", false);
    });

    // Toggle button
    var a11y_dyslexia = document.getElementById("a11y-dyslexia");
    if (a11y_dyslexia) {
        a11y_dyslexia.addEventListener("click", function(event) {
            if (document.body.classList.contains("dyslexia")) {
                a11y_dyslexia_disable();
                a11y_dyslexia.classList.remove("btn-success");
                a11y_dyslexia.classList.add("btn-primary");
            } else {
                a11y_dyslexia_enable();
                a11y_dyslexia.classList.remove("btn-primary");
                a11y_dyslexia.classList.add("btn-success");
            }
        });
    }
});

/*
 * Site Search
 *   Powered by Lunr.js
 *   Thanks https://palant.info/2020/06/04/the-easier-way-to-use-lunr-search-with-hugo/
 */

window.addEventListener("DOMContentLoaded", function(event)
{
  var index = null;
  var lookup = null;
  var queuedTerm = null;

  var form = document.getElementById("sitesearch");
  var input = document.getElementById("sitesearch-input");

  form.addEventListener("submit", function(event)
  {
    event.preventDefault();

    var term = input.value.trim();
    if (!term)
      return;

    startSearch(term);
  }, false);

  function startSearch(term)
  {
    // Start icon animation.
    form.setAttribute("data-running", "true");

    if (index)
    {
      // Index already present, search directly.
      search(term);
    }
    else if (queuedTerm)
    {
      // Index is being loaded, replace the term we want to search for.
      queuedTerm = term;
    }
    else
    {
      // Start loading index, perform the search when done.
      queuedTerm = term;
      initIndex();
    }
  }

  function searchDone()
  {
    // Stop icon animation.
    form.removeAttribute("data-running");

    queuedTerm = null;
  }

  function initIndex()
  {
    var request = new XMLHttpRequest();
    request.open("GET", site_uri.concat("/search.json"));
    request.responseType = "json";
    request.addEventListener("load", function(event)
    {
      lookup = {};
      index = lunr(function()
      {
        // Set language
        //this.use(lunr.en);

        this.ref("uri");

        // If you added more searchable fields to the search index, list them here.
        this.field("title");
        this.field("content");
        this.field("categories");
        this.field("tags");

        for (var doc of request.response)
        {
          this.add(doc);
          lookup[doc.uri] = doc;
        }
      });

      // Search index is ready, perform the search now
      search(queuedTerm);
    }, false);
    request.addEventListener("error", searchDone, false);
    request.send(null);
  }

  function search(term)
  {
    var results = index.search(term);

    // The element where search results should be displayed, adjust as needed.
    resultsContainer = "#search-results";
    var target = document.querySelector(resultsContainer);

    // Prevent closing results if clicked
    target.addEventListener("click", function(event){
        event.stopPropagation();
    });

    // Close reuslts if clicked outside element
    window.addEventListener("click", function (){
        target.textContent = "";
    });

    while (target.firstChild)
      target.removeChild(target.firstChild);

    var title = document.createElement("h3");
    title.className = "search-title";

    var close = document.createElement("button");
    close.className = "close";
    close.textContent = "×";
    close.addEventListener("click", function(event) {
        target.textContent = "";
    });

    if (results.length == 0) {
      title.textContent = `No results found for “${term}”`;
    } else if (results.length == 1) {
      title.textContent = `Found one result for “${term}”`;
    } else {
      title.textContent = `Found ${results.length} results for “${term}”`;
    }

    target.appendChild(title);
    target.appendChild(close);
    
    // Set page title
    //document.title = title.textContent;

    var template = document.getElementById("search-result");
    for (var result of results)
    {
      var doc = lookup[result.ref];

      // Fill out search result template, adjust as needed.
      var element = template.content.cloneNode(true);
      element.querySelector(".search-result-link").href = doc.uri;
      // element.querySelector(".search-result-read").href = doc.uri;
      element.querySelector(".search-result-link").textContent = doc.title;
      element.querySelector(".search-result-summary").textContent = doc.content;
      target.appendChild(element);
    }
    // title.scrollIntoView(true);

    searchDone();
  }
}, false);
