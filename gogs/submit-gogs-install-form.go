package main

import (
	"fmt"
	"github.com/PuerkitoBio/goquery"
	"log"
	"net/http"
	"net/url"
    "net/http/httputil"
	"os"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s <username> <install URL>\n", os.Args[0])
		os.Exit(1)
	}
	username := os.Args[1]
	rawUrl := os.Args[2]

	installUrl, err := url.Parse(rawUrl)
	if err != nil {
		log.Fatal(err)
	}
    domain := installUrl.Host

	doc, err := goquery.NewDocument(installUrl.String())
	if err != nil {
		log.Fatal(err)
	}

	// Populate params with existing existing form values.
	params := url.Values{}
	doc.Find(".form").Find("input, select").Each(func(_ int, s *goquery.Selection) {
		if n, ok := s.Attr("name"); ok {
			v, _ := s.Attr("value")
			params.Add(n, v)
		}
	})

	params.Set("db_type", "SQLite3")
	params.Set("app_name", domain)
	params.Set("run_user", username)
	params.Set("admin_name", username)
	params.Set("admin_email", username+"@"+domain)
	params.Set("smtp_host", domain)

	res, err := http.PostForm(installUrl.String(), params)
	if err != nil {
		log.Fatal(err)
	}

	if res.StatusCode != 301 {
        dump, err := httputil.DumpResponse(res, true)
        if err != nil {
            panic(err)
        }
		fmt.Fprintf(os.Stderr, "%s: %s\n", res.Status, installUrl.String(), string(dump))
        os.Exit(1)
	}
}

