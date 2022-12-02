package main

import (
	"flag"
	"log"
	"os"
	"path"
	"regexp"
	"strings"
	"sync"
	"time"
	// aws deps:
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

func main() {
	var logger = log.New(os.Stderr, "", 1)
	var concurrency, sleepmseconds int
	var download, frombucket, fromprefix, tobucket, prefix string
	var keeppath bool
	var err error
    var filter string

	flag.IntVar(&concurrency, "concurrency", 10,
		"Number of concurrent connections to use.")
	flag.IntVar(&sleepmseconds, "sleep-mseconds", 0,
		"The time (microseconds) to wait between each move (copy operation).")
	flag.StringVar(&frombucket, "from-bucket", "",
		"S3 Bucket to copy contents from. (required)")
	flag.StringVar(&fromprefix, "from-prefix", "",
		"Optional S3 prefix to copy contents from.")
	flag.StringVar(&tobucket, "to-bucket", "",
		"S3 Bucket to copy contents to. (required)")
	flag.StringVar(&prefix, "to-prefix", "",
		"Optional folder (prefix) to copy contents to."+
			"  This may \nbe an actual folder or a S3 path depending"+
			" on whether we\nare copying to a bucket or to the"+
			" file system.")
	flag.StringVar(&download, "download", "",
		"This flag signals that files shall be downloaded to the"+
			" computer and\nnot synced across buckets.  The argument is"+
			" the folder to download to.")
	flag.BoolVar(&keeppath, "keep-path", false,
		"When copying, whether to keep the whole s3 key path")
	flag.StringVar(&filter, "filter", ".*",
		"Filter incoming files by regexp")
	flag.Parse()

	re := regexp.MustCompile(filter)

	if frombucket == "" || fromprefix == "" ||
		(tobucket == "" && download == "") {

		log.Fatalln("Recall that from-bucket, from-prefix," +
			" and a destination (either to-bucket or download)" +
			" are required.")
	}
	if download != "" {
		if err = os.MkdirAll(download, 0770); err != nil {
			log.Fatalln("Cannot create download folder. :(")
		}
		prefix = download
	} else if prefix != "" && prefix[len(prefix)-1] != '/' {
		prefix = prefix + "/"
	}

	// aws session for copiers
	mysession, err := session.NewSession(&aws.Config{
		Region: aws.String(getEnv("AWS_REGION", "eu-central-1"))})
	if err != nil {
		log.Fatalln("Unable to open an aws session")
	}
	svc := s3.New(mysession)
	downloader := s3manager.NewDownloader(mysession)

	logger.Println("bucket", frombucket, "bucket", tobucket,
		"concurrency", concurrency, "toprefix:", prefix)
	lines := read_list_s3(frombucket, fromprefix, 2000)

	wg := new(sync.WaitGroup)
	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for item := range lines {
				if !re.MatchString(item) {
					continue
				}
				if sleepmseconds == 0 {
				} else if sleepmseconds > 0 {
					time.Sleep(time.Duration(sleepmseconds) * time.Millisecond)
				} else {
					log.Fatalln("Negative microseconds, really?")
				}
				fields := strings.Split(item, "/")
				var destkey string
				if keeppath {
					destkey = item
				} else {
					destkey = fields[len(fields)-1]
				}
				if download == "" {
					copy_s3(frombucket, item, tobucket, prefix + destkey, svc)
				} else {
					destfile := path.Join(download, destkey)
					download_s3(frombucket, item, destfile, downloader)
				}
			}
		}()
	}
	log.Println("wait")
	wg.Wait()

	log.Println("process ended! YAY!")
}

func read_list_s3(bucket string, prefix string, buffsize int) <-chan string {
	ch := make(chan string, buffsize)
	log.Printf("aws s3 ls %s/%s\n", bucket, prefix)
	go func() {
		defer close(ch)
		sess, err := session.NewSession(&aws.Config{
			Region: aws.String(getEnv("AWS_REGION", "eu-central-1"))})

		// Create S3 service client
		svc := s3.New(sess)

		// Get the items list
		req := &s3.ListObjectsV2Input{Bucket: aws.String(bucket),
			Prefix: aws.String(prefix)}
		err = svc.ListObjectsV2Pages(req,
			func(resp *s3.ListObjectsV2Output, lastPage bool) bool {
				for _, item := range resp.Contents {
					ch <- *item.Key
				}
				return true
			})
		if err != nil {
			log.Fatalln("Unable to list items in bucket %q, %v", bucket, err)
		}

	}()
	return ch
}

// The following two functions are almost verbatim from
// <https://docs.aws.amazon.com/sdk-for-go/api/service/s3/>
func copy_s3(frombucket string, fromitem string, bucket string,
	item string, svc *s3.S3) {
	// source
	source := frombucket + "/" + fromitem
    source = strings.ReplaceAll(source, "+", "%2B")

	// perform the copy
	_, err := svc.CopyObject(&s3.CopyObjectInput{
		Bucket:            aws.String(bucket),
		CopySource:        aws.String(source),
		Key:               aws.String(item),
	})

	if err != nil {
		log.Printf("Unable to copy %q to %q, %v\n",
			source, bucket+"/"+item, err)
	} else {
		// Wait to see if the item got copied
		err = svc.WaitUntilObjectExists(&s3.HeadObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String(item)})
		if err != nil {
			log.Println("Error occurred while waiting for %q to be"+
				" copied to %q, %v", source, bucket+"/"+item, err)
		} else {
			log.Printf("Successfully copied %q to %q.", source, bucket+"/"+item)
		}
	}
}

func download_s3(bucket string, key string, filename string,
	downloader *s3manager.Downloader) {
	s3path := bucket + "/" + key
	// Create the folder if necessary
	err := os.MkdirAll(path.Dir(filename), 0700)
	if err != nil {
		log.Printf("failed to create file %q, %v", filename, err)
		return
	}
	// Create a file to write the S3 Object contents to.
	f, err := os.Create(filename)
	if err != nil {
		log.Printf("failed to create file %q, %v", filename, err)
		return
	}
	defer f.Close()

	// Write the contents of S3 Object to the file
	n, err := downloader.Download(f, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		log.Printf("failed to download %q, %v", s3path, err)
		return
	}
	log.Printf("%q downloaded, %d bytes\n", s3path, n)
	return
}

func getEnv(key string, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultVal
}
