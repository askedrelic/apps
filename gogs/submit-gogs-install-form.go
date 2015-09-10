package main

import (
	"crypto/rand"
	"fmt"
	"github.com/PuerkitoBio/goquery"
	"log"
	"math/big"
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

	passwd, err := generatePassword(16)
	if err != nil {
		log.Fatal(err)
	}
	params.Set("db_type", "SQLite3")
	params.Set("app_name", domain)
	params.Set("run_user", username)
	params.Set("admin_name", username)
	params.Set("admin_email", username+"@"+domain)
	params.Set("admin_passwd", passwd)
	params.Set("admin_confirm_passwd", passwd)
	params.Set("smtp_host", domain)

	res, err := http.PostForm(installUrl.String(), params)
	if err != nil {
		log.Fatal(err)
	}

	if res.StatusCode == 301 {
		fmt.Printf("%s\n", passwd)
	} else {
        dump, err := httputil.DumpResponse(res, true)
        if err != nil {
            panic(err)
        }
		fmt.Fprintf(os.Stderr, "%s: %s\n", res.Status, installUrl.String(), string(dump))
	}
}

var passwordChars = "abcdefghjkrtvxyz2346789"

func generatePassword(n int) (string, error) {
	str := ""
	for i := 1; i <= n; i++ {
		rnum, err := rand.Int(rand.Reader, big.NewInt(int64(len(passwordChars))))
		if err != nil {
			return "", err
		}
		c := string(passwordChars[rnum.Int64()])
		str += c
	}
	return str, nil
}
