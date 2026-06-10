# URMC Test HS Slurm jobs

See [USER_GUIDE.md](../../USER_GUIDE.md#site-specific-jobs).

```bash
cp jobs/urmc_test/config.env.example jobs/urmc_test/config.env
cp jobs/urmc_test/demographics_file.csv.example jobs/urmc_test/demographics_file.csv
cp jobs/urmc_test/subjects_list.txt.example jobs/urmc_test/subjects_list.txt
# Edit config.env, demographics, and subjects (gitignored)
./jobs/urmc_test/submit.sh
```

Uses flat BIDS (`jobs/urmc_test/bids_config.json` with `"session": null`).
