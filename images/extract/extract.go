package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
)

func main() {
	outDir := flag.String("C", "/", "output directory to extact files to") // in honour of tar

	flag.Parse()

	files := flag.Args()

	errs := make(chan error, len(files))

	log.Printf("writing %d files to %q in parallel", len(files), *outDir)

	copyingWorkGroup := &sync.WaitGroup{}

	for _, fileName := range files {
		copyingWorkGroup.Add(1)
		go doCopy(copyingWorkGroup, fileName, *outDir, errs)
	}

	filesWritten := 0
	errorLoggingWorkGroup := &sync.WaitGroup{}
	go func() {
		errorLoggingWorkGroup.Add(1)
		for err := range errs {
			if err == nil {
				filesWritten++
				continue
			}
			log.Print(err.Error())
		}
		errorLoggingWorkGroup.Done()
	}()

	copyingWorkGroup.Wait()
	close(errs)
	errorLoggingWorkGroup.Wait()
	log.Printf("wrote %d files to %q", filesWritten, *outDir)
}

func doCopy(copyingWorkGroup *sync.WaitGroup, fileName, outDir string, errs chan error) {
	defer copyingWorkGroup.Done()

	// TODO: support directories

	inputFile, err := os.Open(fileName)
	if err != nil {
		errs <- fmt.Errorf("error opening %q: %w", fileName, err)
		return
	}
	defer inputFile.Close()

	inputFileInfo, err := inputFile.Stat()
	if err != nil {
		errs <- fmt.Errorf("cannot stat %q: %w", fileName, err)
		return
	}

	outputPath := filepath.Join(outDir, fileName)
	outputFile, err := os.OpenFile(outputPath, os.O_CREATE|os.O_RDWR, inputFileInfo.Mode())
	if err != nil {
		errs <- fmt.Errorf("error opening %q for writing: %w", outputPath, err)
		return
	}
	defer outputFile.Close()

	// when a file is being overwritten it needs an explicit chmod
	err = outputFile.Chmod(inputFileInfo.Mode())
	if err != nil {
		errs <- fmt.Errorf("cannot chmod %q: %w", outputPath, err)
		return
	}

	_, err = io.Copy(outputFile, inputFile)
	if err != nil {
		errs <- fmt.Errorf("error writing to %q: %w", outputPath, err)
		return
	}

	log.Printf("copied %q to %q", fileName, outputPath)
	errs <- nil
}
