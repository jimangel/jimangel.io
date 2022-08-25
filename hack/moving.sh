############################## run one folder at a time
############################## fix featured image manually (rename / update cover)
############################## this will get all the files, update the markdown, rename and move them to images...
export IMG_PATH="/Users/jimangel/jimangel.io/static/img/" # must be FULL PATH and end with a slash

# move and rename (on a MAC it creates a backup file in sed)
export PREFIX="free-ssl-"
for i in $(ls -lah | awk '{print $9}' | grep '.png\|jpg\|jpeg\|gif'); do export NEW_FILE="${IMG_PATH}${PREFIX}${i}" && export NEW_PATH="/img/${PREFIX}${i}" && mv ${i} ${NEW_FILE} && sed -i'' -e "s~${i}~${NEW_PATH}~g" index.md && rm index.md-e; done && export POST_FOLDER=$(basename $PWD) && mv index.md ../"${POST_FOLDER}.md" && cd ../ && ls -lah ${POST_FOLDER} && rm -rf ${POST_FOLDER} && rm .DS_Store

            # !! manually fix the featured cover image !!

############################## help / revert image move
for i in $(ls -lah ${IMG_PATH} | awk '{print $9}' | grep ${PREFIX}); do mv ${IMG_PATH}${i} ./${i#${PREFIX}}; done

############################## fixing the prefix issue
export PREFIX="google-cloud-vpn-pfsense-"
# delete the files in /img path
for i in $(ls -lah | awk '{print $9}' | grep '.png\|jpg\|jpeg\|gif'); do rm ${IMG_PATH}${PREFIX}${i}; done
# put them back
for i in $(ls -lah | awk '{print $9}' | grep '.png\|jpg\|jpeg\|gif'); do export NEW_FILE="${IMG_PATH}${PREFIX}${i}" && mv ${i} ${NEW_FILE}; done
 
############################## TODO: use this for converting markdown images to local repo...