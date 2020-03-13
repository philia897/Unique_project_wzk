#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sfs.h"
#define CRC_POLY 0x4c11db7

extern recordSize_A;  // structure A's size also the record's size;
extern errmsg;
extern version_num;

static unsigned long table[256];   // the crc_table


//function declaration
static unsigned long bitrev(unsigned long input, int bw);
void crc32_init(unsigned long poly);
unsigned long crc32(void* input, int len);
//end

static unsigned long bitrev(unsigned long input, int bw)
{
	int i;
	unsigned long var;
	var = 0;
	for(i=0;i<bw;i++)
	{
		if(input & 0x01)
		{
			var |= 1<<(bw-1-i);
		}
		input>>=1;
	}
	return var;
}

void crc32_init(unsigned long poly)
{
	int i;
	int j;
	unsigned long c;

	poly=bitrev(poly,32);
	for(i=0; i<256; i++)
	{
		c = i;
		for (j=0; j<8; j++)
		{
			if(c&1)
			{
				c=poly^(c>>1);
			}
			else
			{
				c=c>>1;
			}

		}
		table[i] = c;
	}
}

unsigned long crc32(void* input, int len)
{
	int i;
	unsigned long crc = 0xFFFFFFFF;
	unsigned char index;
	unsigned char* pch;
	pch = (unsigned char*)input;
	crc32_init(CRC_POLY);
	for(i=0;i<len;i++)
	{
		index = (unsigned char)(crc^*pch);
		crc = (crc>>8)^table[index];
		pch++;
	}
	return crc^0xFFFFFFFF;
}

SFSDatabase* sfsDatabaseCreate()
{
    SFSDatabase* db = (SFSDatabase*)malloc(sizeof(SFSDatabase));
    memset(db, 0, sizeof(SFSDatabase));
    if(db==NULL) return db;
    db->magic = 'maho';
    db->size = sizeof(SFSDatabase);
    db->version = version_num;
    db->tableNum = 0;
    version_num++;

    return db;
}

void sfsDatabaseRelease(SFSDatabase* db)
{
    int i = db->tableNum;
    for(i-- ; i >= 0; i--)
    {
        free(db->table[i]);
    }
    free(db);
}

SFSTable* sfsDatabaseAddTable(SFSDatabase *db, uint32_t storSize, const SFSVarchar *recordMeta)
{

    return sfsTableCreate(storSize , recordMeta , db);
}

//functions about save

int dbHead2buf(SFSDatabase* db , char * buf , int freeSize)
{
    int i = 0;
    for( ; i < db->tableNum;i++) db->table[i] = db->table[i]->database;  // change table[] to offset
    put2buf(db, 84, buf , freeSize);
    return 0;
}

int put2buf(void * content, int size, void * buf , int freeSize)  // copy some content to buffer , fail return -1
{
    int i = 0;
    if(size > freeSize) return -1;
    for( ; i < size; i++)
    {
        *(char*)buf = *(char*)content;
        buf++;
        content++;
    }
    return 0;
}

void Lock_addr_db_table(SFSDatabase * db)     // to change value "database" of table
{
    int i = 0;
    if(db->tableNum>0){
        db->table[0]->database = 84;
        for( i = 1; i < db->tableNum ; i++)
        {
            db->table[i]->database = (uint32_t)(db->table[i-1]->database) + db->table[i-1]->size;

        }
    }
}

int table2buf(SFSTable* table, char * buf)    // you should ensure the buffer is large enough  copy to the buffer
{
    uint32_t sizeOfBuf = table->size ;
    char * workptr = table;       // work pointer of table

    // to get every record's pointers' offsets
    uint32_t i = 0 , j = 0;
    SFSVarchar** varcharptr = NULL;
    uint32_t metaLen = table->recordMeta->len;      // to store the info of meta
    char meta_buf[metaLen];
    for(i = 0; i< metaLen; i++) meta_buf[i] = table->recordMeta->buf[i];
    workptr = ptrOffset(workptr , sizeof(SFSTable));
    for(i = 0; i< table->recordNum; i++)
    {
        for(j = 0; j < metaLen; j++)
        {
            if(meta_buf[j]==0)  // its a pointer , maybe point to a varchar
            {
                varcharptr = workptr;
                if(*varcharptr){            // actually point to something
                    *varcharptr = countOffset(table, (*varcharptr));  // change the ptr to offset
                }
                workptr = ptrOffset(workptr , sizeof(SFSVarchar*));
            }
            else{
                workptr = ptrOffset(workptr , meta_buf[j]);
            }

        }
    }
    //end
    table->lastVarchar = countOffset(table , table->lastVarchar);  // to set the last varchar offset
    table->recordMeta = countOffset(table , table->recordMeta);  // to set the record meta offset

    return put2buf(table , table->size , buf , sizeOfBuf);
}

int sfsDatabaseSave(char *fileName, SFSDatabase* db)
{
    char * buf = malloc(db->size);memset(buf, 0, db->size);  // to make a buffer
    if(!buf)  return -1;                                  // failed to malloc
    char * workptr = buf ;                               // workptr is a ptr work on buf
    uint32_t i = 0, len = 0;                          // i is a counter, len store the workptr going to offset length

    Lock_addr_db_table(db);            // to change the "database" value of tables
    workptr = ptrOffset(workptr, sizeof(SFSDatabase));  // offset to the first table address
    for(i = 0; i < db->tableNum; i++)          // to store all tables to the buffer first
    {
        len = db->table[i]->size;
        table2buf(db->table[i], workptr);
        workptr = ptrOffset(workptr, len);
    }
    dbHead2buf(db, buf, 84);       // store the db head to buffer
    // calculate crc32 to head
    workptr = ptrOffset(buf , 8);
    len = crc32(workptr, db->size-8);
    workptr = ptrOffset(buf , 4);
    uint32_t *crc = workptr;
    *crc = len;free(crc);
    // crc end
    FILE* fp = fopen(fileName, "wb");
    if(!fp) { strcpy(errmsg, "fail to open a file when try to write.") ; return -1 ;}    //errmsg update
    fwrite(buf, 1, db->size, fp);
    fclose(fp);

    return 0;
}


// functions about load

SFSTable* buf2table(char * buf , SFSDatabase* db)      // change the info in buffer to table type and return the ptr of table
{
    SFSTable * table = buf;
    //head change
    table->lastVarchar = ptrOffset(table, (uint32_t)(table->lastVarchar));
    table->recordMeta = ptrOffset(table , (uint32_t)(table->recordMeta));//printf("%d\n", countOffset(table, table->recordMeta));
    table->database = db;
   //end
    uint32_t i = 0 , j = 0;
    char * workptr = table;
    SFSVarchar** varcharptr = NULL;
    uint32_t metaLen = table->recordMeta->len;      // to store the info of meta
    char meta_buf[metaLen];
    for(i = 0; i< metaLen; i++) meta_buf[i] = table->recordMeta->buf[i];
    workptr = ptrOffset(workptr , sizeof(SFSTable));
    for(i = 0; i< table->recordNum; i++)
    {
        for(j = 0; j < metaLen; j++)
        {
            if(meta_buf[j]==0)  // its a pointer , maybe point to a varchar
            {
                varcharptr = workptr;
                if(*varcharptr){            // actually point to something
                    *varcharptr = ptrOffset(table, (*varcharptr));  // change the offset to pointer
                }
                workptr = ptrOffset(workptr , sizeof(SFSVarchar*));
            }
            else{
                workptr = ptrOffset(workptr , meta_buf[j]);
            }

        }
    }

    return table;
}

SFSDatabase* sfsDatabaseCreateLoad(char *fileName)
{
    // open the file and read the file head to a database
    SFSDatabase* db;
    FILE* fp = fopen(fileName, "rb");
    if(!fp) {strcpy(errmsg, "fail to open the file when try to read"); return NULL;} // errmsg update
    char *buf_db= malloc(sizeof(SFSDatabase));memset(buf_db ,0, 84 );
    fread(buf_db, 1, 84, fp);
    db = (SFSDatabase*)buf_db;
    // database head created
    char *buf = NULL;
    uint32_t i = 0, len = 0; // len used to store the size of one table

    if(db->tableNum>0)
    {
        for(i = 0; i<db->tableNum-1; i++)
        {
            len = db->table[i+1]-db->table[i];
            buf = malloc(len);memset(buf,0,len); // room get
            fread(buf, 1, len, fp);
            db->table[i] = buf2table(buf , db);
        }
        len = db->size-(uint32_t)(db->table[i]);
        buf = malloc(len);memset(buf,0,len);
        fread(buf, 1, len, fp);
        db->table[i] = buf2table(buf, db);
    }
    fclose(fp);

    return db;
}



