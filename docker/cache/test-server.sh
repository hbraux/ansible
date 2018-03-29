# Server Ready
curl -s $DOCKER_HOST/

echo "12345678">samplefile.txt

# FTP upload
echo -e "quote USER anonymous\ncd pub\nmkdir dir\ncd dir\nput samplefile.txt\nput samplefile.txt other.txt\nquit" | ftp -n -v $DOCKER_HOST

# HTTP list
curl -s $DOCKER_HOST/pub/dir

# HTTP download
rm -f samplefile.txt
wget $DOCKER_HOST/pub/dir/samplefile.txt
rm -f samplefile.txt

# FTP delete
echo -e "quote USER anonymous\ncd pub/dir\ndel other.txt\nquit" | ftp -n -v $DOCKER_HOST

