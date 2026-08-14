module ServeBlob
  private
    def serve_blob(blob, disposition:)
      redirect_to blob.url(disposition: disposition, expires_in: 5.minutes), allow_other_host: true
    end
end
