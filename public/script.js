"use strict";

(function(){
    const crawlSubmitButton = document.getElementById("crawl-submit");
    const crawlTextarea = document.getElementById("crawl-textarea");
    const crawlFormBody = document.getElementById("crawl-form-body");

    let websocket = new WebSocket(`ws://${document.location.host}/websocket`);

    websocket.onerror = function(event) {
        window.alert(event);
        websocket = new WebSocket(`ws://${document.location.host}/websocket`);
    };

    crawlSubmitButton.addEventListener("click", function(event) {
        event.preventDefault();

        crawlFormBody.innerHTML = "";

        const urls = crawlTextarea.value.split("\n");
        websocket.send(JSON.stringify({type: "crawl", urls}))
    });

    function handleCrawlResult(result) {
        let url = document.createElement("td");
        url.innerText = result.url;

        let time = document.createElement("td");
        time.innerText = `${(result.crawl_time*1000).toFixed(2)}ms`;

        let resultNode = document.createElement("td");
        if (result.error_message) {
            resultNode.innerText = result.error_message;
        } else {
            resultNode.innerText = result.date;
        }

        let tr = document.createElement("tr");
        tr.appendChild(url);
        tr.appendChild(resultNode);
        tr.appendChild(time);

        crawlFormBody.appendChild(tr);
    }

    websocket.onmessage = function(event) {
        const response = JSON.parse(event.data);
        switch (response.type) {
            case "result":
                handleCrawlResult(response.crawl_result);
                break;
        }
    };
})();
